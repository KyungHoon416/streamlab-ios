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
    private(set) var source: Source = .bundled
    private let titleID: String
    private let session: CatalogSession
    private var generation = 0
    private var loadTask: Task<Void, Never>?
    private var sampleTask: Task<Void, Never>?
    private var seekTask: Task<Void, Never>?
    private var foreground = true
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
        let seconds = item.duration.seconds
        duration = seconds.isFinite && seconds > 0 ? seconds : 0
        let current = player.currentTime().seconds
        if !isSeeking { position = current.isFinite ? max(0, current) : 0 }
        if item.status != .readyToPlay || player.timeControlStatus == .waitingToPlayAtSpecifiedRate {
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
        isSeeking = true
        position = destination
        seekTask = Task { [weak self, weak player] in
            guard let player else { return }
            let completed = await player.seek(to: CMTime(seconds: destination, preferredTimescale: 600),
                                              toleranceBefore: .zero, toleranceAfter: .zero)
            guard !Task.isCancelled, let self, self.generation == ticket, self.session.isActive else { return }
            self.isSeeking = false
            if completed && playAfterSeek && self.foreground {
                self.wantsPlayback = true
                player.play()
            }
            _ = self.sample(ticket: ticket)
        }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        waitingSince = nil
        if !active {
            wantsPlayback = false
            player?.pause()
            waitingSince = nil
        }
        // Returning to the foreground never starts audio/video automatically.
    }

    func stop() {
        generation += 1
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

    private func fail(_ message: String) {
        stop()
        status = .failed(message)
    }

    deinit {
        loadTask?.cancel()
        sampleTask?.cancel()
        seekTask?.cancel()
    }
}
