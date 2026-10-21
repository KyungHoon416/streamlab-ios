import AVFoundation
import Combine
import Foundation
import OSLog
import StreamLabDesignSystem
import StreamLabDomain
import StreamLabPresentation

/// Owns one player for one presentation and one profile session.
@MainActor final class PlaybackModel: ObservableObject {
    enum Source: String, CaseIterable, Identifiable {
        case bundled = "오프라인 데모", hls = "HLS 스트리밍"
        case downloadedHLS = "다운로드한 HLS 샘플"
        case hlsAudio = "HLS 오디오 비교 · 영어 / 화면 해설"
        case hlsStandardAudio = "HLS 오디오 비교 · 일반 영어만"
        case episode1 = "연속 재생 데모 · 1화"
        case episode2 = "연속 재생 데모 · 2화"
        case episode3 = "연속 재생 데모 · 3화"
        case hlsEpisode1 = "HLS 테스트 시즌 · 1화"
        case hlsEpisode2 = "HLS 테스트 시즌 · 2화"
        var id: String { rawValue }
        var isHLS: Bool {
            switch self {
            case .hls, .hlsAudio, .hlsStandardAudio, .hlsEpisode1, .hlsEpisode2, .downloadedHLS: true
            default: false
            }
        }
        var nextEpisode: Source? {
            switch self {
            case .episode1: .episode2
            case .episode2: .episode3
            case .hlsEpisode1: .hlsEpisode2
            default: nil
            }
        }
        var progressID: String {
            switch self {
            case .bundled: "bundled-demo-v1"
            case .hls, .downloadedHLS: "apple-bipbop-v1"
            case .hlsAudio: "apple-trailer-audio-v1"
            case .hlsStandardAudio: "apple-bipbop-standard-v1"
            case .episode1: "demo-series-episode-1-v1"
            case .episode2: "demo-series-episode-2-v1"
            case .episode3: "demo-series-episode-3-v1"
            case .hlsEpisode1: "hls-series-episode-1-v1"
            case .hlsEpisode2: "hls-series-episode-2-v1"
            }
        }
        var url: URL? {
            switch self {
            case .downloadedHLS: nil // Resolved only through the profile-scoped download store.
            case .bundled, .episode1, .episode2, .episode3: Bundle.module.url(forResource: "playback-demo", withExtension: "mp4")
            case .hls, .hlsEpisode1: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")
            case .hlsStandardAudio: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8")
            case .hlsAudio, .hlsEpisode2: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8")
            }
        }
    }
    enum Status: Equatable {
        case idle, loading, playing, paused, ended, failed(String)
        var label: String {
            switch self {
            case .idle: "재생 준비"
            case .loading: "영상을 불러오는 중…"
            case .playing: "재생 중"
            case .paused: "일시 정지"
            case .ended: "재생 완료"
            case .failed(let message): message
            }
        }
    }

    @Published private(set) var player: AVPlayer?
    let pictureInPicture = PlaybackPictureInPicture()
    @Published private(set) var pipPossible = false
    @Published private(set) var pipRunning = false
    @Published private(set) var pipMessage = ""
    private var playbackAllowed: Bool { session.isActive && !interruptionPolicy.isInterrupted && !audioResumePending }
    private var interruptionPolicy = PlaybackInterruptionPolicy()
    private var audioResumePending = false
    @Published private(set) var captionsWhenMuted = true
    private var muteCaptionPolicy = MuteCaptionPolicy()
    private var outputIsMuted = false
    private var audioEventObserver: PlaybackAudioEventObserver?
    @Published private(set) var status: Status = .idle
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isSeeking = false
    struct SubtitleOption: Identifiable {
        let id: String
        let label: String
        var language: String? = nil
        var audioRole: AudioRole = .standard
        var forcedOnly = false
    }
    @Published private(set) var subtitleOptions: [SubtitleOption] = []
    @Published private(set) var selectedSubtitleID = "off"
    @Published private(set) var subtitleText = ""
    @Published private(set) var subtitleMessage = ""
    @Published private(set) var subtitlesLoading = false
    @Published private(set) var subtitleLoadFailed = false
    @Published private(set) var canDisableSubtitles = true
    @Published private(set) var audioOptions: [SubtitleOption] = []
    @Published private(set) var selectedAudioID = "automatic"
    @Published private(set) var audioMessage = ""
    @Published private(set) var audioLoading = false
    @Published private(set) var audioLoadFailed = false
    private var audioTask: Task<Void, Never>?
    private var audioGroup: AVMediaSelectionGroup?
    private var nativeAudio: [String: AVMediaSelectionOption] = [:]
    private var subtitleTask: Task<Void, Never>?
    private var subtitleGroup: AVMediaSelectionGroup?
    private var nativeSubtitles: [String: AVMediaSelectionOption] = [:]
    private var sidecarSubtitles: [String: [SubtitleCue]] = [:]
    @Published private(set) var source: Source = .bundled
    @Published private(set) var nextEpisodeSeconds: Int?
    private var autoAdvance = AutoAdvanceCountdown()
    private var nextEpisodeStarted: ContinuousClock.Instant?
    private var nowPlayingOwner: UUID?
    private var nowPlayingTitle = "StreamLab"
    private var nowPlayingArtworkURL: URL?
    private let titleID: String
    private let session: CatalogSession
    private var offlineLease: UUID?
    private let progressLog = Logger(subsystem: "com.example.streamlab.demo", category: "PlaybackProgress")
    private var diagnostics = PlaybackDiagnostics()
    private weak var videoLayer: AVPlayerLayer?
    private var diagnosticAttempt: UUID?
    private var lastObservedBitrate: Double?
    private let qoeLog = Logger(subsystem: "com.example.streamlab.demo", category: "PlaybackQoE")

    func attachVideoLayer(_ layer: AVPlayerLayer) { videoLayer = layer }

    private func observePlayback(_ next: PlaybackDiagnostics.State) {
        let previous = diagnostics.state
        let accepted = diagnostics.observe(next, at: ProcessInfo.processInfo.systemUptime,
                                           generation: diagnostics.generation)
        guard previous != next else { return }
        qoeLog.notice("transition from=\(previous.rawValue, privacy: .public) to=\(next.rawValue, privacy: .public) accepted=\(accepted)")
    }

    private func sampleDiagnostics(item: AVPlayerItem, player: AVPlayer) {
        guard diagnosticAttempt != nil else { return }
        if item.status == .readyToPlay && diagnostics.state == .preparing {
            observePlayback(.ready)
        }
        if diagnostics.state != .preparing {
            if isSeeking { observePlayback(.seeking) }
            else {
                switch status {
                case .playing: observePlayback(.playing)
                case .paused:
                    if diagnostics.state != .paused {
                        qoeLog.notice("pause_snapshot position=\(self.position) wantsPlayback=\(self.wantsPlayback) foreground=\(self.foreground) interrupted=\(self.interruptionPolicy.isInterrupted) seeking=\(self.isSeeking) rate=\(player.rate) timeControl=\(player.timeControlStatus.rawValue)")
                    }
                    observePlayback(.paused)
                case .loading: observePlayback(.buffering)
                case .ended: observePlayback(.ended)
                case .idle, .failed: break
                }
            }
        }
        if let layer = videoLayer, layer.player === player, layer.isReadyForDisplay {
            let hadFrame = diagnostics.firstFrameSeconds != nil
            diagnostics.frameReady(at: ProcessInfo.processInfo.systemUptime, generation: diagnostics.generation)
            if !hadFrame, let seconds = diagnostics.firstFrameSeconds {
                qoeLog.notice("first_frame_ready_seconds=\(seconds)")
            }
        }
        if let bitrate = item.accessLog()?.events.last?.observedBitrate,
           bitrate.isFinite, bitrate > 0, bitrate != lastObservedBitrate {
            lastObservedBitrate = bitrate
            qoeLog.notice("observed_bitrate_bps=\(bitrate)")
        }
    }

    private func finishDiagnostics() {
        guard let attempt = diagnosticAttempt else { return }
        diagnostics.finish(at: ProcessInfo.processInfo.systemUptime)
        let frame = diagnostics.firstFrameSeconds.map { String($0) } ?? "not-observed"
        qoeLog.notice("summary attempt=\(attempt.uuidString, privacy: .public) source=\(self.source.progressID, privacy: .public) first_frame_ready_seconds=\(frame, privacy: .public) rebuffer_count=\(self.diagnostics.rebufferCount) rebuffer_seconds=\(self.diagnostics.rebufferSeconds) failures=\(self.diagnostics.failureCount) invalid_transitions=\(self.diagnostics.invalidTransitionCount)")
        diagnosticAttempt = nil
    }

    @Published private(set) var retryBudget = PlaybackRetryBudget()
    @Published private(set) var failureIsMediaReset = false
    private var mediaResetObserver: PlaybackMediaResetObserver?
    private var itemEndObserver: PlaybackItemEndObserver?
    private var itemReachedEnd = false
    private var audioSessionOwner: UUID?
    private let syncDeviceID: String?
    private var syncedProgress: SyncedPlaybackProgress?
    private var syncRestartPending = false
    @Published private(set) var syncMessage = ""

    #if DEBUG
    private var injectedMediaReset = false
    private var injectedUnrequestedPause = false
    #endif
    var canRetryPlayback: Bool {
        guard session.isActive, foreground, case .failed = status else { return false }
        return retryBudget.remaining > 0
    }

    func retryPlayback() {
        guard canRetryPlayback, retryBudget.consume() else { return }
        load()
    }

    private func handleMediaReset(ticket: Int) {
        guard generation == ticket, session.isActive, diagnosticAttempt != nil else { return }
        // Never read/reset a potentially invalid player position into saved progress.
        progressReady = false
        if status == .ended { stop(); return }
        fail("기기의 미디어 서비스가 재시작되었습니다. 재시도를 눌러 재생을 복구해 주세요.", mediaReset: true)
    }

    private var generation = 0
    private var loadTask: Task<Void, Never>?
    private var sampleTask: Task<Void, Never>?
    private var seekTask: Task<Void, Never>?
    private var seekGeneration = 0
    private var seekStarted: ContinuousClock.Instant?
    @Published private(set) var seekMessage = ""
    #if DEBUG
    private var injectedSeekStall = false
    #endif
    private var foreground = true
    private var playbackIntentGeneration = 0
    private var wantsPlayback = true
    private var waitingSince: Date?
    private var attempted = false
    private var needsInitialPosition = true
    private var progressReady = false
    private var restoringPosition = false
    private var lastProgressSave: ContinuousClock.Instant?
    @Published private(set) var resumeMessage = ""

    private var progressEnabled: Bool {
        #if DEBUG
        !ProcessInfo.processInfo.arguments.contains("--ui-test-disable-resume")
        #else
        true
        #endif
    }

    init(titleID: String, session: CatalogSession, syncDeviceID: String? = nil) {
        self.syncDeviceID = syncDeviceID
        self.titleID = titleID
        self.session = session
        captionsWhenMuted = session.languages.preferences.captionsWhenMuted ?? true
        session.register(self)
        pictureInPicture.onStop = { [weak self] in
            guard let self else { return }
            self.qoeLog.notice("pause_reason=pip_closed")
            self.playbackIntentGeneration += 1
            self.interruptionPolicy.cancelResume()
            self.audioResumePending = false
            self.wantsPlayback = false
            self.player?.pause()
            self.saveProgress()
            self.pipRunning = false
        }
        pictureInPicture.onFailure = { [weak self] message in self?.pipMessage = message }
    }

    var canSeek: Bool {
        player?.currentItem?.status == .readyToPlay && duration > 0 && !isSeeking && !syncRestartPending
    }

    func load(_ source: Source? = nil) {
        stop()
        if let source {
            self.source = source
            retryBudget.reset()
        }
        guard session.isActive else { return }
        failureIsMediaReset = false
        diagnostics.begin(at: ProcessInfo.processInfo.systemUptime)
        let attempt = UUID()
        diagnosticAttempt = attempt
        lastObservedBitrate = nil
        qoeLog.notice("attempt_started attempt=\(attempt.uuidString, privacy: .public) source=\(self.source.progressID, privacy: .public)")
        status = .loading
        wantsPlayback = foreground
        let ticket = generation
        mediaResetObserver = PlaybackMediaResetObserver { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleMediaReset(ticket: ticket)
            }
        }
        audioEventObserver = PlaybackAudioEventObserver { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket, self.session.isActive else { return }
                self.handleAudioEvent(event)
            }
        }
        let repository = session.repository
        let profile = session.profile
        let id = titleID
        loadTask = Task { [weak self] in
            do {
                let title = try await repository.detail(id: id, profile: profile)
                guard !Task.isCancelled, let self, self.generation == ticket, self.session.isActive else { return }
                guard let title, title.canView(in: profile) else {
                    self.fail("이 프로필에서는 재생할 수 없는 콘텐츠입니다.")
                    return
                }
                self.nowPlayingTitle = title.name
                self.nowPlayingArtworkURL = StreamLabTheme.bundledArtworkURL(seed: title.visualSeed)
                if let deviceID = self.syncDeviceID {
                    let identity = ProgressIdentity(profileID: profile.id, titleID: id, sourceID: self.source.progressID)
                    let progress = await PlaybackSyncDemo.coordinator.open(identity: identity, deviceID: deviceID)
                    guard !Task.isCancelled, self.generation == ticket, self.session.isActive else { return }
                    self.syncedProgress = progress
                    self.syncMessage = "가상 기기 \(deviceID) · 서버 진도 불러옴"
                }
                self.prepare(ticket: ticket)
            } catch {
                guard !Task.isCancelled, let self, self.generation == ticket else { return }
                self.fail("재생 권한을 확인하지 못했습니다. 다시 시도해 주세요.")
            }
        }
    }

    private func prepare(ticket: Int) {
        var url = source.url
        if source == .downloadedHLS {
            guard let (savedURL, lease) = OfflineDownloadStore.shared.acquire(session: session, titleID: titleID) else {
                fail("다운로드 파일이 없거나 이용 기간이 만료되어 재생할 수 없습니다. 다시 다운로드해 주세요.")
                return
            }
            url = savedURL
            offlineLease = lease
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-resource-always-missing") ||
            (!attempted && ProcessInfo.processInfo.arguments.contains("--playback-missing-resource-once")) {
            url = nil
        }
        #endif
        attempted = true
        guard let url else { fail("데모 영상을 찾을 수 없습니다. 다시 시도해 주세요."); return }
        let owner = UUID()
        audioSessionOwner = owner
        PlaybackAudioSession.shared.activate(owner: owner) { [weak self] succeeded in
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket, self.session.isActive,
                      self.audioSessionOwner == owner else {
                    PlaybackAudioSession.shared.release(owner: owner)
                    return
                }
                guard succeeded else {
                    self.fail("오디오 재생을 준비하지 못했습니다. 다시 시도해 주세요.")
                    return
                }
                self.preparePlayer(url: url, ticket: ticket)
            }
        }
    }

    private func preparePlayer(url: URL, ticket: Int) {
        let player = AVPlayer(url: url)
        // Audio continues with the screen locked or when automatic PiP is unavailable.
        player.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        self.player = player
        let nowPlayingID = UUID()
        nowPlayingOwner = nowPlayingID
        PlaybackNowPlaying.shared.begin(owner: nowPlayingID, player: player, title: nowPlayingTitle,
            subtitle: "StreamLab · \(source.rawValue)", artworkURL: nowPlayingArtworkURL) { [weak self] action in
                guard let self, self.generation == ticket, self.session.isActive else { return }
                self.handleRemoteAction(action, origin: .systemRemote)
            }
        observeItemEnd(ticket: ticket)
        player.appliesMediaSelectionCriteriaAutomatically = false
        prepareSubtitles(player: player, ticket: ticket)
        prepareAudio(player: player, ticket: ticket)
        // Wait for item readiness and restore its position before starting playback.
        waitingSince = Date()
        // Sampling and notification effects are isolated to MainActor.
        // Weak ownership is released before every suspension.
        sampleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self?.sample(ticket: ticket) == true else { return }
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { return }
            }
        }
    }

    private func observeItemEnd(ticket: Int) {
        itemEndObserver = nil
        guard let item = player?.currentItem else { return }
        let seekTicket = seekGeneration
        itemEndObserver = PlaybackItemEndObserver(item: item) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.generation == ticket,
                      self.seekGeneration == seekTicket, self.session.isActive,
                      !self.isSeeking else { return }
                self.itemReachedEnd = true
                self.qoeLog.notice("item_end source=\(self.source.progressID, privacy: .public) position=\(self.position) duration=\(self.duration)")
                _ = self.sample(ticket: ticket)
            }
        }
    }

    private func sample(ticket: Int) -> Bool {
        guard generation == ticket, session.isActive, let player, let item = player.currentItem else { return false }
        pictureInPicture.checkStartTimeout()
        if foreground {
            pictureInPicture.setAutomaticStartEnabled(source.isHLS && wantsPlayback && !isSeeking && player.rate > 0)
        }
        pipPossible = source.isHLS && pictureInPicture.possible && !isSeeking && item.status == .readyToPlay
        pipRunning = pictureInPicture.isRunning
        if pipRunning, !isSeeking, playbackAllowed {
            // Native PiP transport controls modify AVPlayer directly.
            wantsPlayback = player.timeControlStatus != .paused
        }
        if item.status == .failed {
            fail("영상을 재생할 수 없습니다. 연결 상태를 확인하고 다시 시도해 주세요.")
            return false
        }
        if isSeeking, let seekStarted, seekStarted.duration(to: .now) >= .seconds(8) {
            seekGeneration += 1
            seekTask?.cancel(); seekTask = nil
            self.seekStarted = nil
            isSeeking = false
            wantsPlayback = false
            player.pause()
            item.cancelPendingSeeks()
            observeItemEnd(ticket: ticket)
            restoringPosition = false
            seekMessage = "재생 위치 이동이 지연되어 취소했습니다. 다시 이동하거나 재생해 주세요."
        }
        let seconds = item.duration.seconds
        duration = seconds.isFinite && seconds > 0 ? seconds : 0
        let current = player.currentTime().seconds
        if !isSeeking { position = current.isFinite ? max(0, current) : 0 }
        if item.status == .readyToPlay && diagnostics.state == .preparing {
            observePlayback(.ready)
        }
        if needsInitialPosition && item.status == .readyToPlay && duration > 0 {
            needsInitialPosition = false
            if progressEnabled, let saved = initialProgressPosition() {
                #if DEBUG
                progressLog.notice("restore profile=\(self.session.profile.id, privacy: .private) title=\(self.titleID, privacy: .private) source=\(self.source.progressID, privacy: .public) seconds=\(saved, privacy: .private)")
                #endif
                restoringPosition = true
                seek(to: saved)
                return true
            }
            #if DEBUG
            progressLog.notice("fresh profile=\(self.session.profile.id, privacy: .private) title=\(self.titleID, privacy: .private) source=\(self.source.progressID, privacy: .public) seconds=0")
            #endif
            if source.isHLS {
                // No saved record for this profile: explicitly position the VOD at zero.
                seek(to: 0)
                return true
            }
            progressReady = true
            if playbackAllowed && wantsPlayback { player.play() }
        }
        // The actual end notification is authoritative even if HLS duration and
        // the last presented sample differ, or timeControlStatus is still waiting.
        if itemReachedEnd && !isSeeking {
            waitingSince = nil
            status = .ended
        } else if item.status != .readyToPlay || (wantsPlayback && player.timeControlStatus == .waitingToPlayAtSpecifiedRate) {
            status = .loading
            if waitingSince == nil { waitingSince = Date() }
            if playbackAllowed, let waitingSince, Date().timeIntervalSince(waitingSince) > 30 {
                fail("영상 로딩 시간이 초과되었습니다. 다시 시도해 주세요.")
                return false
            }
        } else {
            waitingSince = nil
            if !isSeeking && duration > 0 && position >= duration - 0.15 && player.rate == 0 {
                status = .ended
            } else {
                status = player.rate > 0 ? .playing : .paused
            }
        }
        sampleDiagnostics(item: item, player: player)
        #if DEBUG
        if !injectedUnrequestedPause, status == .playing, position >= 0.1,
           ProcessInfo.processInfo.arguments.contains("--ui-test-unrequested-pause-once") {
            injectedUnrequestedPause = true
            qoeLog.notice("debug_injection=unrequested_player_pause")
            player.pause() // Preserve intent to reproduce a paused engine with a Play button.
        }
        if !injectedMediaReset, status == .playing, position >= 1,
           ProcessInfo.processInfo.arguments.contains("--ui-test-media-reset-once") {
            injectedMediaReset = true
            NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
        }
        #endif
        if status == .ended, source.nextEpisode != nil, foreground, wantsPlayback {
            if autoAdvance.state == .idle {
                autoAdvance.start()
                nextEpisodeStarted = .now
            }
            if let start = nextEpisodeStarted {
                let elapsed = start.duration(to: .now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                let ready = autoAdvance.advance(elapsed: seconds)
                nextEpisodeSeconds = autoAdvance.remaining
                if ready {
                    playNextEpisode()
                    return false // old sampling task must not continue after load()
                }
            }
        }
        updateSubtitleText()
        if let owner = nowPlayingOwner {
            PlaybackNowPlaying.shared.update(owner: owner, position: position, duration: duration,
                rate: isSeeking ? 0 : Double(player.rate), canSeek: canSeek)
        }
        if lastProgressSave.map({ $0.duration(to: .now) >= .seconds(5) }) ?? true {
            saveProgress()
        }
        return true
    }

    func cancelNextEpisode() {
        autoAdvance.cancel()
        nextEpisodeStarted = nil
        nextEpisodeSeconds = nil
    }

    func playNextEpisode() {
        guard session.isActive, foreground, status == .ended, let next = source.nextEpisode else { return }
        load(next) // Saves old item, cancels tasks and rechecks repository permission.
    }

    private func handleAudioEvent(_ event: PlaybackAudioEvent) {
        if case .volumeChanged = event {} else {
            qoeLog.notice("audio_event=\(String(describing: event), privacy: .public)")
        }
        switch event {
        case .volumeChanged(let volume):
            guard volume.isFinite else { return }
            outputIsMuted = volume == 0
            applyMuteCaptions()
        case .interruptionBegan(let preventsAutomaticResume):
            interruptionPolicy.begin(wantsPlayback: wantsPlayback || audioResumePending, preventsAutomaticResume: preventsAutomaticResume)
            playbackIntentGeneration += 1
            audioResumePending = false
            wantsPlayback = false
            player?.pause()
            cancelNextEpisode()
            waitingSince = nil
        case .outputDisconnected:
            playbackIntentGeneration += 1
            interruptionPolicy.cancelResume()
            audioResumePending = false
            wantsPlayback = false
            player?.pause()
            cancelNextEpisode()
        case .interruptionEnded(let shouldResume):
            guard interruptionPolicy.end(shouldResume: shouldResume),
                  !isSeeking, !syncRestartPending, let owner = audioSessionOwner,
                  player?.currentItem?.status == .readyToPlay, !itemReachedEnd else { return }
            let ticket = generation
            let intent = playbackIntentGeneration
            audioResumePending = true
            PlaybackAudioSession.shared.reactivate(owner: owner) { [weak self] success in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == ticket,
                          self.playbackIntentGeneration == intent, self.session.isActive,
                          self.audioSessionOwner == owner else { return }
                    self.audioResumePending = false
                    guard success, self.playbackAllowed, !self.isSeeking, !self.syncRestartPending else { return }
                    self.wantsPlayback = true
                    self.player?.play()
                    _ = self.sample(ticket: ticket)
                }
            }
        }
        _ = sample(ticket: generation)
        saveProgress()
    }

    private enum TransportOrigin: String { case screenButton = "screen_button", systemRemote = "system_remote" }

    private func handleRemoteAction(_ action: PlaybackNowPlaying.Action, origin: TransportOrigin) {
        qoeLog.notice("transport_action=\(String(describing: action), privacy: .public) origin=\(origin.rawValue, privacy: .public) wantsPlayback=\(self.wantsPlayback) position=\(self.position)")
        guard session.isActive, let player else { return }
        switch action {
        case .pause:
            // Pause also cancels the auto-resume intent of an in-flight seek.
            playbackIntentGeneration += 1
            interruptionPolicy.cancelResume()
            audioResumePending = false
            wantsPlayback = false
            player.pause()
        case .play:
            guard playbackAllowed, !syncRestartPending, !isSeeking, player.currentItem?.status == .readyToPlay else { return }
            if status == .ended { seek(to: 0, playAfterSeek: true); return }
            progressReady = true
            wantsPlayback = true
            player.play()
        case .toggle:
            handleRemoteAction((wantsPlayback || interruptionPolicy.isInterrupted || audioResumePending) ? .pause : .play, origin: origin)
            return
        case .skip(let delta):
            seek(to: player.currentTime().seconds + delta)
        case .seek(let position):
            seek(to: position)
        }
        _ = sample(ticket: generation)
        saveProgress()
    }

    func togglePlayback() {
        guard !syncRestartPending else { return }
        guard session.isActive, foreground, player != nil else { return }
        // During a system interruption, tapping the control cancels pending resume.
        if interruptionPolicy.isInterrupted || audioResumePending {
            handleRemoteAction(.pause, origin: .screenButton)
            return
        }
        guard status != .loading, !isSeeking else { return }
        // Match the visible control, not stale intent left behind by AVPlayer stopping.
        handleRemoteAction(status == .playing ? .pause : .play, origin: .screenButton)
    }

    func seek(to seconds: Double, playAfterSeek: Bool = false) {
        guard playbackAllowed, canSeek, seconds.isFinite, let player else { return }
        autoAdvance.reset()
        nextEpisodeStarted = nil
        nextEpisodeSeconds = nil
        itemEndObserver = nil
        itemReachedEnd = false
        let destination = min(duration, max(0, seconds))
        let ticket = generation
        seekGeneration += 1
        let seekTicket = seekGeneration
        let resumeAfterSeek = wantsPlayback || playAfterSeek
        let intentTicket = playbackIntentGeneration
        seekStarted = .now
        seekMessage = ""
        isSeeking = true
        observePlayback(.seeking)
        if !resumeAfterSeek { player.pause() }
        position = destination
        subtitleText = ""
        seekTask = Task { [weak self, weak player] in
            guard let player else { return }
            let completed = await player.seek(to: CMTime(seconds: destination, preferredTimescale: 600),
                                              toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600),
                                              toleranceAfter: CMTime(seconds: 0.1, preferredTimescale: 600))
            guard !Task.isCancelled, let self, self.generation == ticket,
                  self.seekGeneration == seekTicket, self.session.isActive else { return }
            #if DEBUG
            // Deterministically exercise the watchdog without relying on network timing.
            if !self.injectedSeekStall && ProcessInfo.processInfo.arguments.contains("--ui-test-stall-seek-once") {
                self.injectedSeekStall = true
                return
            }
            #endif
            self.seekStarted = nil
            self.isSeeking = false
            if completed {
                self.progressReady = true
                if self.restoringPosition { self.resumeMessage = "저장된 위치에서 이어보는 중" }
            }
            self.restoringPosition = false
            self.observeItemEnd(ticket: ticket)
            self.wantsPlayback = completed && resumeAfterSeek && self.playbackAllowed && self.playbackIntentGeneration == intentTicket
            if self.wantsPlayback { player.play() } else { player.pause() }
            if !completed { self.seekMessage = "재생 위치 이동이 취소되었습니다. 다시 시도해 주세요." }
            _ = self.sample(ticket: ticket)
        }
    }

    func setForeground(_ active: Bool) {
        guard foreground != active else { return }
        foreground = active
        qoeLog.notice("foreground_changed active=\(active)")
        waitingSince = nil
        if !active {
            // Preserve the user's playing/paused intent. The audio session and AVPlayer
            // policy own background continuation, independently of automatic PiP success.
            cancelNextEpisode()
            saveProgress()
        } else {
            // Refresh visible state without forcing a paused/interrupted player to play.
            _ = sample(ticket: generation)
        }
    }

    func togglePictureInPicture() {
        guard session.isActive, foreground else { return }
        pipMessage = ""
        if pictureInPicture.isRunning {
            pictureInPicture.restore()
        } else if source.isHLS && pipPossible {
            cancelNextEpisode()
            pictureInPicture.start()
        }
        pipRunning = pictureInPicture.isRunning
    }

    private func initialProgressPosition() -> Double? {
        if syncDeviceID != nil {
            guard let saved = syncedProgress?.snapshot.position, saved >= 1,
                  saved < duration - min(5, duration * 0.05) else { return nil }
            return saved
        }
        return session.progress.position(titleID: titleID, sourceID: source.progressID, duration: duration)
    }

    func saveProgress() {
        guard progressEnabled, session.isActive, progressReady, !isSeeking, !syncRestartPending,
              let player, let item = player.currentItem, item.status == .readyToPlay else { return }
        let seconds = player.currentTime().seconds
        if syncDeviceID != nil {
            if let syncedProgress, seconds.isFinite, seconds >= 0 {
                PlaybackSyncDemo.coordinator.submit(.checkpoint(seconds), to: syncedProgress)
                if syncedProgress.conflicted { syncMessage = "다른 기기의 진도가 변경되었습니다. 닫았다 다시 열어 주세요." }
            }
        } else {
            session.progress.save(titleID: titleID, sourceID: source.progressID,
                                  position: seconds, duration: item.duration.seconds)
            syncMessage = session.progress.persistenceError ?? ""
        }
        lastProgressSave = .now
    }

    func restartFromBeginning() {
        guard canSeek, !syncRestartPending else { return }
        guard let syncedProgress else {
            session.progress.restart(titleID: titleID, sourceID: source.progressID)
            if let error = session.progress.persistenceError {
                syncMessage = error
                return
            }
            resumeMessage = ""
            seek(to: 0)
            return
        }
        syncRestartPending = true
        player?.pause()
        wantsPlayback = false
        let ticket = generation
        let write = PlaybackSyncDemo.coordinator.submit(.restart, to: syncedProgress)
        Task { @MainActor [weak self] in
            let reply = await write.value
            guard let self, self.generation == ticket, self.session.isActive else { return }
            self.syncRestartPending = false
            guard reply?.accepted == true else {
                self.syncMessage = "진도가 변경되어 초기화하지 못했습니다. 닫았다 다시 열어 주세요."
                return
            }
            self.resumeMessage = ""
            self.syncMessage = "처음부터 보기 · 서버 진도 초기화됨"
            self.seek(to: 0)
        }
    }

    func stop() {
        if let offlineLease { OfflineDownloadStore.shared.release(offlineLease); self.offlineLease = nil }
        if let owner = nowPlayingOwner {
            PlaybackNowPlaying.shared.end(owner: owner)
            nowPlayingOwner = nil
        }
        pictureInPicture.setAutomaticStartEnabled(false)
        mediaResetObserver = nil
        audioEventObserver = nil
        muteCaptionPolicy = MuteCaptionPolicy()
        interruptionPolicy = PlaybackInterruptionPolicy()
        audioResumePending = false
        itemEndObserver = nil
        itemReachedEnd = false
        finishDiagnostics()
        pictureInPicture.invalidate()
        pipPossible = false
        pipRunning = false
        pipMessage = ""
        autoAdvance.reset()
        nextEpisodeStarted = nil
        nextEpisodeSeconds = nil
        saveProgress()
        syncedProgress = nil
        syncRestartPending = false
        syncMessage = ""
        needsInitialPosition = true
        progressReady = false
        restoringPosition = false
        lastProgressSave = nil
        resumeMessage = ""
        generation += 1
        seekGeneration += 1
        seekStarted = nil
        seekMessage = ""
        audioTask?.cancel(); audioTask = nil
        audioGroup = nil; nativeAudio = [:]; audioOptions = []
        selectedAudioID = "automatic"; audioMessage = ""; audioLoading = false; audioLoadFailed = false
        subtitleTask?.cancel(); subtitleTask = nil
        subtitleGroup = nil
        nativeSubtitles = [:]; sidecarSubtitles = [:]
        subtitleOptions = []; selectedSubtitleID = "off"; subtitleText = ""
        subtitleMessage = ""; subtitleLoadFailed = false; subtitlesLoading = false; canDisableSubtitles = true
        loadTask?.cancel(); loadTask = nil
        sampleTask?.cancel(); sampleTask = nil
        seekTask?.cancel(); seekTask = nil
        player?.pause()
        player?.currentItem?.cancelPendingSeeks()
        player?.replaceCurrentItem(with: nil)
        player = nil
        if let owner = audioSessionOwner {
            audioSessionOwner = nil
            PlaybackAudioSession.shared.release(owner: owner)
        }
        isSeeking = false
        position = 0; duration = 0
        waitingSince = nil
        status = .idle
    }

    var subtitleLabel: String {
        selectedSubtitleID == "unavailable" ? "사용 불가" :
            subtitleOptions.first(where: { $0.id == selectedSubtitleID })?.label ?? "끄기"
    }

    func selectSubtitle(_ id: String, persist: Bool = true) {
        guard session.isActive, let item = player?.currentItem else { return }
        guard id == "off" || subtitleOptions.contains(where: { $0.id == id }) else { return }
        if let group = subtitleGroup {
            if id == "off" {
                guard group.allowsEmptySelection else { return }
                item.select(nil, in: group)
            } else {
                guard let option = nativeSubtitles[id], option.isPlayable else {
                    subtitleMessage = "이 자막은 현재 선택할 수 없습니다. 목록을 다시 불러와 주세요."
                    return
                }
                item.select(option, in: group)
            }
        }
        selectedSubtitleID = id
        if persist {
            muteCaptionPolicy.userSelected(isMuted: outputIsMuted)
            let language = subtitleOptions.first(where: { $0.id == id })?.language
            if id == "off" {
                session.languages.setSubtitles(.off)
            } else if let language {
                session.languages.setSubtitles(.language(language))
            } else {
                subtitleMessage = "언어 정보가 없는 트랙입니다. 이번 영상에만 적용하며 기존 선호 언어는 유지합니다."
            }
        }
        updateSubtitleText()
    }

    func setCaptionsWhenMuted(_ enabled: Bool) {
        guard session.isActive else { return }
        captionsWhenMuted = enabled
        session.languages.setCaptionsWhenMuted(enabled)
        applyMuteCaptions()
    }

    private func applyMuteCaptions() {
        guard session.isActive, player?.currentItem != nil else { return }
        let languagePreference = session.languages.preferences.mutedSubtitlePreference(
            deviceLanguage: Locale.preferredLanguages.first ?? "ko")
        let index = SubtitleLanguageResolver.index(for: languagePreference,
            languages: subtitleOptions.map(\.language), forcedOnly: subtitleOptions.map(\.forcedOnly),
            defaultIndex: nil, allowsOff: false)
        let candidate = index.map { subtitleOptions[$0].id }
        if let choice = muteCaptionPolicy.update(isMuted: outputIsMuted, enabled: captionsWhenMuted,
                                                selected: selectedSubtitleID, candidate: candidate) {
            selectSubtitle(choice, persist: false)
        }
    }

    private func updateSubtitleText() {
        subtitleText = isSeeking ? "" : SubRip.text(at: position, in: sidecarSubtitles[selectedSubtitleID] ?? [])
    }

    private func prepareSubtitles(player: AVPlayer, ticket: Int) {
        if !source.isHLS {
            for (id, label) in [("ko", "한국어 · 데모"), ("en", "English · Demo")] {
                #if DEBUG
                // Deterministic missing-language fixture; never affects production/HLS.
                if source == .episode2 && id == "ko" &&
                    ProcessInfo.processInfo.arguments.contains("--ui-test-missing-korean-episode") { continue }
                #endif
                guard let url = Bundle.module.url(forResource: "playback-demo-\(id)", withExtension: "srt"),
                      let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let cues = SubRip.parse(text)
                guard !cues.isEmpty else { continue }
                sidecarSubtitles[id] = cues
                subtitleOptions.append(SubtitleOption(id: id, label: label, language: id))
            }
            subtitleMessage = subtitleOptions.isEmpty ? "이 영상에 제공되는 자막이 없습니다." : "무음 데모용 안내 자막입니다."
            restoreSubtitles()
            return
        }
        guard let item = player.currentItem else { return }
        subtitleLoadFailed = false
        subtitleOptions = []
        nativeSubtitles = [:]
        subtitleGroup = nil
        selectedSubtitleID = "off"
        subtitleText = ""
        canDisableSubtitles = true
        subtitlesLoading = true
        // Only the weak model is captured across loading. Results are bound to this item/session.
        subtitleTask = Task { [weak self] in
            do {
                let group = try await item.asset.loadMediaSelectionGroup(for: .legible)
                guard !Task.isCancelled, let self, self.generation == ticket,
                      self.session.isActive, self.player?.currentItem === item else { return }
                self.subtitlesLoading = false
                self.subtitleGroup = group
                guard let group else {
                    self.subtitleMessage = "이 영상에 제공되는 자막이 없습니다. 저장된 선호 언어는 유지됩니다."
                    return
                }
                let available = self.source == .downloadedHLS
                    ? ((item.asset as? AVURLAsset)?.assetCache?.mediaSelectionOptions(in: group) ?? [])
                    : group.options
                for (index, option) in available.filter({ $0.isPlayable }).enumerated() {
                    let id = "native-\(index)"
                    self.nativeSubtitles[id] = option
                    self.subtitleOptions.append(SubtitleOption(id: id, label: option.displayName, language: MediaLanguageResolver.normalized(option.extendedLanguageTag ?? option.locale?.identifier),
                        forcedOnly: option.hasMediaCharacteristic(.containsOnlyForcedSubtitles)))
                }
                self.canDisableSubtitles = group.allowsEmptySelection
                guard !self.subtitleOptions.isEmpty else {
                    if group.allowsEmptySelection { item.select(nil, in: group) }
                    self.selectedSubtitleID = "unavailable"
                    self.subtitleMessage = "재생 가능한 자막 트랙이 없습니다. 저장된 선호 언어는 유지됩니다."
                    return
                }
                self.restoreSubtitles()

            } catch {
                guard !Task.isCancelled, let self, self.generation == ticket, self.session.isActive else { return }
                self.subtitlesLoading = false
                self.subtitleLoadFailed = true
                self.subtitleMessage = "자막 목록을 불러오지 못했습니다. 다시 시도해 주세요."
            }
        }
    }

    func retrySubtitles() {
        guard session.isActive, let player, source.isHLS, !subtitlesLoading else { return }
        subtitleTask?.cancel()
        subtitleMessage = ""
        prepareSubtitles(player: player, ticket: generation)
    }

    private func restoreSubtitles() {
        let preference = session.languages.preferences.subtitles
        let defaultIndex = subtitleOptions.firstIndex { nativeSubtitles[$0.id] == subtitleGroup?.defaultOption }
        let index = SubtitleLanguageResolver.index(for: preference, languages: subtitleOptions.map(\.language),
                                                forcedOnly: subtitleOptions.map(\.forcedOnly),
                                                defaultIndex: subtitleGroup == nil ? nil : defaultIndex,
                                                allowsOff: canDisableSubtitles)
        selectSubtitle(index.map { subtitleOptions[$0].id } ?? "off", persist: false)
        if preference == .off && !canDisableSubtitles {
            subtitleMessage = "이 영상의 필수 자막은 끌 수 없습니다. 저장된 끄기 설정은 유지됩니다."
        } else if case .language(let language) = preference,
                  MediaLanguageResolver.index(for: preference, languages: subtitleOptions.map(\.language), defaultIndex: nil, allowsOff: true) == nil {
            subtitleMessage = "저장된 자막 언어(\(language))가 없어 기본 자막 또는 끄기를 적용했습니다. 선호 언어는 유지됩니다."
        }
        applyMuteCaptions()
    }

    func selectAudio(_ id: String) {
        guard session.isActive, let item = player?.currentItem, let group = audioGroup else { return }
        if id == "automatic" {
            session.languages.setAudio(.automatic)
            applyAudioPreference(item: item, group: group)
        } else if let option = nativeAudio[id], option.isPlayable {
            item.select(option, in: group)
            selectedAudioID = id
            if let language = audioOptions.first(where: { $0.id == id })?.language {
                session.languages.setAudio(.language(language), role: option.hasMediaCharacteristic(.describesVideoForAccessibility) ? .audioDescription : .standard)
                audioMessage = "선택한 오디오 언어와 종류를 이 프로필에 저장했습니다."
            } else {
                audioMessage = "언어 정보가 없는 트랙입니다. 이번 영상에만 적용하며 기존 선호 언어는 유지합니다."
            }
        }
    }

    private func applyAudioPreference(item: AVPlayerItem, group: AVMediaSelectionGroup) {
        let preferences = session.languages.preferences
        let preference = preferences.audio
        let defaultIndex = audioOptions.firstIndex { nativeAudio[$0.id] == group.defaultOption }
        let index = AudioPreferenceResolver.index(for: preference, role: preferences.audioRole,
                                                  languages: audioOptions.map(\.language),
                                                  roles: audioOptions.map(\.audioRole), defaultIndex: defaultIndex)
        guard let index else {
            selectedAudioID = "unavailable"
            audioMessage = "재생 가능한 대체 오디오 트랙이 없습니다. 저장된 선호 설정은 유지됩니다."
            return
        }
        let id = audioOptions[index].id
        guard let option = nativeAudio[id], option.isPlayable else {
            selectedAudioID = "unavailable"
            audioMessage = "이 오디오는 현재 선택할 수 없습니다. 목록을 다시 불러와 주세요."
            return
        }
        item.select(option, in: group)
        selectedAudioID = preference == .automatic ? "automatic" : id
        audioMessage = ""
        if case .language(let language) = preference,
           MediaLanguageResolver.index(for: preference, languages: audioOptions.map(\.language), defaultIndex: nil, allowsOff: true) == nil {
            audioMessage = "저장된 오디오 언어(\(language))가 없어 기본 트랙을 재생합니다. 선호 설정은 유지됩니다."
        } else if case .language = preference, let role = preferences.audioRole,
                  audioOptions[index].audioRole != role {
            audioMessage = "저장된 오디오 종류가 없어 같은 언어의 다른 트랙을 재생합니다. 선호 설정은 유지됩니다."
        }
    }

    private func prepareAudio(player: AVPlayer, ticket: Int) {
        guard let item = player.currentItem else { return }
        audioLoading = true
        audioLoadFailed = false
        audioGroup = nil
        audioOptions = []
        nativeAudio = [:]
        selectedAudioID = "automatic"
        audioTask = Task { [weak self] in
            do {
                let group = try await item.asset.loadMediaSelectionGroup(for: .audible)
                guard !Task.isCancelled, let self, self.generation == ticket,
                      self.session.isActive, self.player?.currentItem === item else { return }
                self.audioLoading = false
                self.audioGroup = group
                guard let group else {
                    self.audioMessage = self.source.isHLS ? "선택 가능한 대체 오디오 트랙이 없습니다." : "이 데모 영상은 무음입니다."
                    return
                }
                self.audioOptions = []
                self.nativeAudio = [:]
                let available = self.source == .downloadedHLS
                    ? ((item.asset as? AVURLAsset)?.assetCache?.mediaSelectionOptions(in: group) ?? [])
                    : group.options
                for (index, option) in available.filter({ $0.isPlayable }).enumerated() {
                    let id = "audio-\(index)"
                    self.nativeAudio[id] = option
                    self.audioOptions.append(SubtitleOption(id: id, label: option.displayName,
                        language: MediaLanguageResolver.normalized(option.extendedLanguageTag ?? option.locale?.identifier),
                        audioRole: option.hasMediaCharacteristic(.describesVideoForAccessibility) ? .audioDescription : .standard))
                }
                if self.audioOptions.isEmpty { self.audioMessage = "선택 가능한 오디오 트랙이 없습니다." }
                self.applyAudioPreference(item: item, group: group)
            } catch {
                guard !Task.isCancelled, let self, self.generation == ticket, self.session.isActive else { return }
                self.audioLoading = false
                self.audioLoadFailed = true
                self.audioMessage = "오디오 목록을 불러오지 못했습니다. 다시 시도해 주세요."
            }
        }
    }

    func retryAudio() {
        guard session.isActive, let player, !audioLoading else { return }
        audioTask?.cancel()
        prepareAudio(player: player, ticket: generation)
    }

    private func fail(_ message: String, mediaReset: Bool = false) {
        if diagnosticAttempt != nil { observePlayback(.failed) }
        stop()
        failureIsMediaReset = mediaReset
        status = .failed(message)
    }

    deinit {
        if let offlineLease { Task { @MainActor in OfflineDownloadStore.shared.release(offlineLease) } }
        if let owner = nowPlayingOwner {
            Task { @MainActor in PlaybackNowPlaying.shared.end(owner: owner) }
        }
        if let owner = audioSessionOwner { PlaybackAudioSession.shared.release(owner: owner) }
        audioTask?.cancel()
        subtitleTask?.cancel()
        loadTask?.cancel()
        sampleTask?.cancel()
        seekTask?.cancel()
    }
}

