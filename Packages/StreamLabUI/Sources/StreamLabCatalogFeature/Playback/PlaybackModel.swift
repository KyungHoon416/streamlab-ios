import AVFoundation
import Combine
import Foundation
import StreamLabDomain

/// Owns one player for one presentation and one profile session.
@MainActor final class PlaybackModel: ObservableObject {
    enum Source: String, CaseIterable, Identifiable {
        case bundled = "오프라인 데모", hls = "HLS 스트리밍"
        var id: String { rawValue }
        var url: URL? {
            switch self {
            case .bundled: Bundle.module.url(forResource: "playback-demo", withExtension: "mp4")
            case .hls: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")
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
    @Published private(set) var status: Status = .idle
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var isSeeking = false
    struct SubtitleOption: Identifiable {
        let id: String
        let label: String
    }
    @Published private(set) var subtitleOptions: [SubtitleOption] = []
    @Published private(set) var selectedSubtitleID = "off"
    @Published private(set) var subtitleText = ""
    @Published private(set) var subtitleMessage = ""
    @Published private(set) var subtitlesLoading = false
    @Published private(set) var subtitleLoadFailed = false
    @Published private(set) var canDisableSubtitles = true
    private var subtitleTask: Task<Void, Never>?
    private var subtitleGroup: AVMediaSelectionGroup?
    private var nativeSubtitles: [String: AVMediaSelectionOption] = [:]
    private var sidecarSubtitles: [String: [SubtitleCue]] = [:]
    private(set) var source: Source = .bundled
    private let titleID: String
    private let session: CatalogSession
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

    init(titleID: String, session: CatalogSession) {
        self.titleID = titleID
        self.session = session
        session.register(self)
    }

    var canSeek: Bool {
        player?.currentItem?.status == .readyToPlay && duration > 0 && !isSeeking
    }

    func load(_ source: Source? = nil) {
        stop()
        if let source { self.source = source }
        guard session.isActive else { return }
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
        let player = AVPlayer(url: url)
        self.player = player
        prepareSubtitles(player: player, ticket: ticket)
        if foreground && wantsPlayback { player.play() }
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
            seekMessage = "재생 위치 이동이 지연되어 취소했습니다. 다시 이동하거나 재생해 주세요."
        }
        let seconds = item.duration.seconds
        duration = seconds.isFinite && seconds > 0 ? seconds : 0
        let current = player.currentTime().seconds
        if !isSeeking { position = current.isFinite ? max(0, current) : 0 }
        if item.status != .readyToPlay || (wantsPlayback && player.timeControlStatus == .waitingToPlayAtSpecifiedRate) {
            status = .loading
            if waitingSince == nil { waitingSince = Date() }
            if foreground, let waitingSince, Date().timeIntervalSince(waitingSince) > 30 {
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
        updateSubtitleText()
        return true
    }

    func togglePlayback() {
        guard session.isActive, foreground, let player else { return }
        if status == .ended { seek(to: 0, playAfterSeek: true); return }
        wantsPlayback = player.rate == 0
        if wantsPlayback { player.play() } else { player.pause() }
        _ = sample(ticket: generation)
    }

    func seek(to seconds: Double, playAfterSeek: Bool = false) {
        guard canSeek, seconds.isFinite, let player else { return }
        let destination = min(duration, max(0, seconds))
        let ticket = generation
        seekGeneration += 1
        let seekTicket = seekGeneration
        let resumeAfterSeek = wantsPlayback || playAfterSeek
        let foregroundTicket = foregroundGeneration
        seekStarted = .now
        seekMessage = ""
        isSeeking = true
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
            self.wantsPlayback = completed && resumeAfterSeek && self.foreground && self.foregroundGeneration == foregroundTicket
            if self.wantsPlayback { player.play() } else { player.pause() }
            if !completed { self.seekMessage = "재생 위치 이동이 취소되었습니다. 다시 시도해 주세요." }
            _ = self.sample(ticket: ticket)
        }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        waitingSince = nil
        if !active {
            foregroundGeneration += 1
            wantsPlayback = false
            player?.pause()
            waitingSince = nil
        }
        // Returning to the foreground never starts audio/video automatically.
    }

    func stop() {
        generation += 1
        seekGeneration += 1
        seekStarted = nil
        seekMessage = ""
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
        isSeeking = false
        position = 0; duration = 0
        waitingSince = nil
        status = .idle
    }

    var subtitleLabel: String {
        subtitleOptions.first(where: { $0.id == selectedSubtitleID })?.label ?? "끄기"
    }

    func selectSubtitle(_ id: String) {
        guard session.isActive, let item = player?.currentItem else { return }
        guard id == "off" || subtitleOptions.contains(where: { $0.id == id }) else { return }
        if let group = subtitleGroup {
            guard id != "off" || group.allowsEmptySelection else { return }
            item.select(nativeSubtitles[id], in: group)
        }
        selectedSubtitleID = id
        updateSubtitleText()
    }

    private func updateSubtitleText() {
        subtitleText = isSeeking ? "" : SubRip.text(at: position, in: sidecarSubtitles[selectedSubtitleID] ?? [])
    }

    private func prepareSubtitles(player: AVPlayer, ticket: Int) {
        if source == .bundled {
            for (id, label) in [("ko", "한국어 · 데모"), ("en", "English · Demo")] {
                guard let url = Bundle.module.url(forResource: "playback-demo-\(id)", withExtension: "srt"),
                      let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let cues = SubRip.parse(text)
                guard !cues.isEmpty else { continue }
                sidecarSubtitles[id] = cues
                subtitleOptions.append(SubtitleOption(id: id, label: label))
            }
            subtitleMessage = subtitleOptions.isEmpty ? "이 영상에 제공되는 자막이 없습니다." : "무음 데모용 안내 자막입니다."
            return
        }
        guard let item = player.currentItem else { return }
        subtitleLoadFailed = false
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
                for (index, option) in group.options.enumerated() {
                    let id = "native-\(index)"
                    self.nativeSubtitles[id] = option
                    self.subtitleOptions.append(SubtitleOption(id: id, label: option.displayName))
                }
                self.canDisableSubtitles = group.allowsEmptySelection
                if group.allowsEmptySelection {
                    item.select(nil, in: group)
                } else if let option = group.options.first {
                    item.select(option, in: group)
                    self.selectedSubtitleID = "native-0"
                    self.subtitleMessage = "이 영상의 필수 자막은 끌 수 없습니다."
                }
            } catch {
                guard !Task.isCancelled, let self, self.generation == ticket, self.session.isActive else { return }
                self.subtitlesLoading = false
                self.subtitleLoadFailed = true
                self.subtitleMessage = "자막 목록을 불러오지 못했습니다. 다시 시도해 주세요."
            }
        }
    }

    func retrySubtitles() {
        guard session.isActive, let player, source == .hls, !subtitlesLoading else { return }
        subtitleTask?.cancel()
        subtitleMessage = ""
        prepareSubtitles(player: player, ticket: generation)
    }

    private func fail(_ message: String) {
        stop()
        status = .failed(message)
    }

    deinit {
        subtitleTask?.cancel()
        loadTask?.cancel()
        sampleTask?.cancel()
        seekTask?.cancel()
    }
}

