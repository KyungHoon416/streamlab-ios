import AVFoundation
import Combine
import Foundation
import OSLog
import StreamLabDomain

/// Owns one player for one presentation and one profile session.
@MainActor final class PlaybackModel: ObservableObject {
    enum Source: String, CaseIterable, Identifiable {
        case bundled = "오프라인 데모", hls = "HLS 스트리밍"
        case hlsAudio = "HLS 오디오 비교 · 영어 / 화면 해설"
        case episode1 = "연속 재생 데모 · 1화"
        case episode2 = "연속 재생 데모 · 2화"
        case episode3 = "연속 재생 데모 · 3화"
        var id: String { rawValue }
        var isHLS: Bool {
            switch self {
            case .hls, .hlsAudio: true
            default: false
            }
        }
        var nextEpisode: Source? {
            switch self {
            case .episode1: .episode2
            case .episode2: .episode3
            default: nil
            }
        }
        var progressID: String {
            switch self {
            case .bundled: "bundled-demo-v1"
            case .hls: "apple-bipbop-v1"
            case .hlsAudio: "apple-trailer-audio-v1"
            case .episode1: "demo-series-episode-1-v1"
            case .episode2: "demo-series-episode-2-v1"
            case .episode3: "demo-series-episode-3-v1"
            }
        }
        var url: URL? {
            switch self {
            case .bundled, .episode1, .episode2, .episode3: Bundle.module.url(forResource: "playback-demo", withExtension: "mp4")
            case .hls: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")
            case .hlsAudio: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/adv_dv_atmos/main.m3u8")
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
    private var playbackAllowed: Bool { foreground || pictureInPicture.isRunning }
    @Published private(set) var status: Status = .idle
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isSeeking = false
    struct SubtitleOption: Identifiable {
        let id: String
        let label: String
        var language: String? = nil
        var audioRole: AudioRole = .standard
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
    private let titleID: String
    private let session: CatalogSession
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
                case .paused: observePlayback(.paused)
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
        qoeLog.notice("summary attempt=\(attempt.uuidString, privacy: .public) first_frame_ready_seconds=\(frame, privacy: .public) rebuffer_count=\(self.diagnostics.rebufferCount) rebuffer_seconds=\(self.diagnostics.rebufferSeconds) failures=\(self.diagnostics.failureCount) invalid_transitions=\(self.diagnostics.invalidTransitionCount)")
        diagnosticAttempt = nil
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
    private var foregroundGeneration = 0
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

    init(titleID: String, session: CatalogSession) {
        self.titleID = titleID
        self.session = session
        session.register(self)
        pictureInPicture.onStop = { [weak self] in
            guard let self else { return }
            self.wantsPlayback = false
            self.player?.pause()
            self.saveProgress()
            self.pipRunning = false
        }
        pictureInPicture.onFailure = { [weak self] message in self?.pipMessage = message }
    }

    var canSeek: Bool {
        player?.currentItem?.status == .readyToPlay && duration > 0 && !isSeeking
    }

    func load(_ source: Source? = nil) {
        stop()
        if let source { self.source = source }
        guard session.isActive else { return }
        diagnostics.begin(at: ProcessInfo.processInfo.systemUptime)
        diagnosticAttempt = UUID()
        lastObservedBitrate = nil
        qoeLog.notice("attempt_started")
        status = .loading
        wantsPlayback = foreground
        let ticket = generation
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
                self.prepare(ticket: ticket)
            } catch {
                guard !Task.isCancelled, let self, self.generation == ticket else { return }
                self.fail("재생 권한을 확인하지 못했습니다. 다시 시도해 주세요.")
            }
        }
    }

    private func prepare(ticket: Int) {
        var url = source.url
        #if DEBUG
        if !attempted && ProcessInfo.processInfo.arguments.contains("--playback-missing-resource-once") {
            url = nil
        }
        #endif
        attempted = true
        guard let url else { fail("데모 영상을 찾을 수 없습니다. 다시 시도해 주세요."); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            fail("오디오 재생을 준비하지 못했습니다. 다시 시도해 주세요.")
            return
        }
        let player = AVPlayer(url: url)
        self.player = player
        player.appliesMediaSelectionCriteriaAutomatically = false
        prepareSubtitles(player: player, ticket: ticket)
        prepareAudio(player: player, ticket: ticket)
        // Wait for item readiness and restore its position before starting playback.
        waitingSince = Date()
        // No KVO/notification/periodic-time observer crosses actor boundaries.
        // Weak ownership is released before every suspension.
        sampleTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self?.sample(ticket: ticket) == true else { return }
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { return }
            }
        }
    }

    private func sample(ticket: Int) -> Bool {
        guard generation == ticket, session.isActive, let player, let item = player.currentItem else { return false }
        pictureInPicture.checkStartTimeout()
        pipPossible = source.isHLS && pictureInPicture.possible && !isSeeking && item.status == .readyToPlay
        pipRunning = pictureInPicture.isRunning
        if pipRunning, !isSeeking {
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
            if progressEnabled, let saved = session.progress.position(titleID: titleID, sourceID: source.progressID, duration: duration) {
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
            if foreground && wantsPlayback { player.play() }
        }
        if item.status != .readyToPlay || (wantsPlayback && player.timeControlStatus == .waitingToPlayAtSpecifiedRate) {
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

    func togglePlayback() {
        guard session.isActive, foreground, let player else { return }
        if status == .ended { seek(to: 0, playAfterSeek: true); return }
        progressReady = true
        wantsPlayback = player.rate == 0
        if wantsPlayback { player.play() } else { player.pause() }
        _ = sample(ticket: generation)
    }

    func seek(to seconds: Double, playAfterSeek: Bool = false) {
        guard canSeek, seconds.isFinite, let player else { return }
        autoAdvance.reset()
        nextEpisodeStarted = nil
        nextEpisodeSeconds = nil
        let destination = min(duration, max(0, seconds))
        let ticket = generation
        seekGeneration += 1
        let seekTicket = seekGeneration
        let resumeAfterSeek = wantsPlayback || playAfterSeek
        let foregroundTicket = foregroundGeneration
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
            self.wantsPlayback = completed && resumeAfterSeek && self.playbackAllowed && self.foregroundGeneration == foregroundTicket
            if self.wantsPlayback { player.play() } else { player.pause() }
            if !completed { self.seekMessage = "재생 위치 이동이 취소되었습니다. 다시 시도해 주세요." }
            _ = self.sample(ticket: ticket)
        }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        waitingSince = nil
        if !active && !pictureInPicture.isRunning {
            cancelNextEpisode()
            foregroundGeneration += 1
            wantsPlayback = false
            player?.pause()
            saveProgress()
            waitingSince = nil
        }
        // Returning to the foreground never starts audio/video automatically.
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

    func saveProgress() {
        guard progressEnabled, session.isActive, progressReady, !isSeeking,
              let player, let item = player.currentItem, item.status == .readyToPlay else { return }
        session.progress.save(titleID: titleID, sourceID: source.progressID,
                              position: player.currentTime().seconds, duration: item.duration.seconds)
        lastProgressSave = .now
    }

    func restartFromBeginning() {
        guard canSeek else { return }
        resumeMessage = ""
        seek(to: 0)
    }

    func stop() {
        finishDiagnostics()
        pictureInPicture.invalidate()
        pipPossible = false
        pipRunning = false
        pipMessage = ""
        autoAdvance.reset()
        nextEpisodeStarted = nil
        nextEpisodeSeconds = nil
        saveProgress()
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
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isSeeking = false
        position = 0; duration = 0
        waitingSince = nil
        status = .idle
    }

    var subtitleLabel: String {
        subtitleOptions.first(where: { $0.id == selectedSubtitleID })?.label ?? "끄기"
    }

    func selectSubtitle(_ id: String, persist: Bool = true) {
        guard session.isActive, let item = player?.currentItem else { return }
        guard id == "off" || subtitleOptions.contains(where: { $0.id == id }) else { return }
        if let group = subtitleGroup {
            guard id != "off" || group.allowsEmptySelection else { return }
            item.select(nativeSubtitles[id], in: group)
        }
        selectedSubtitleID = id
        if persist {
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

    private func updateSubtitleText() {
        subtitleText = isSeeking ? "" : SubRip.text(at: position, in: sidecarSubtitles[selectedSubtitleID] ?? [])
    }

    private func prepareSubtitles(player: AVPlayer, ticket: Int) {
        if !source.isHLS {
            for (id, label) in [("ko", "한국어 · 데모"), ("en", "English · Demo")] {
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
        subtitlesLoading = true
        // Only the weak model is captured across loading. Results are bound to this item/session.
        subtitleTask = Task { [weak self] in
            do {
                let group = try await item.asset.loadMediaSelectionGroup(for: .legible)
                guard !Task.isCancelled, let self, self.generation == ticket,
                      self.session.isActive, self.player?.currentItem === item else { return }
                self.subtitlesLoading = false
                self.subtitleGroup = group
                guard let group, !group.options.isEmpty else {
                    self.subtitleMessage = "이 영상에 제공되는 자막이 없습니다."
                    return
                }
                for (index, option) in group.options.filter({ $0.isPlayable }).enumerated() {
                    let id = "native-\(index)"
                    self.nativeSubtitles[id] = option
                    self.subtitleOptions.append(SubtitleOption(id: id, label: option.displayName, language: MediaLanguageResolver.normalized(option.extendedLanguageTag ?? option.locale?.identifier)))
                }
                self.canDisableSubtitles = group.allowsEmptySelection
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
        let index = MediaLanguageResolver.index(for: preference, languages: subtitleOptions.map(\.language),
                                                defaultIndex: subtitleGroup == nil ? nil : defaultIndex,
                                                allowsOff: canDisableSubtitles)
        selectSubtitle(index.map { subtitleOptions[$0].id } ?? "off", persist: false)
        if preference == .off && !canDisableSubtitles {
            subtitleMessage = "이 영상의 필수 자막은 끌 수 없습니다. 저장된 끄기 설정은 유지됩니다."
        } else if case .language(let language) = preference,
                  MediaLanguageResolver.index(for: preference, languages: subtitleOptions.map(\.language), defaultIndex: nil, allowsOff: true) == nil {
            subtitleMessage = "저장된 자막 언어(\(language))가 없어 기본 자막 또는 끄기를 적용했습니다. 선호 언어는 유지됩니다."
        }
    }

    func selectAudio(_ id: String) {
        guard session.isActive, let item = player?.currentItem, let group = audioGroup else { return }
        if id == "automatic" {
            session.languages.setAudio(.automatic)
            applyAudioPreference(item: item, group: group)
        } else if let option = nativeAudio[id] {
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
        guard let index else { return }
        let id = audioOptions[index].id
        item.select(nativeAudio[id], in: group)
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
                for (index, option) in group.options.filter({ $0.isPlayable }).enumerated() {
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

    private func fail(_ message: String) {
        if diagnosticAttempt != nil { observePlayback(.failed) }
        stop()
        status = .failed(message)
    }

    deinit {
        audioTask?.cancel()
        subtitleTask?.cancel()
        loadTask?.cancel()
        sampleTask?.cancel()
        seekTask?.cancel()
    }
}

