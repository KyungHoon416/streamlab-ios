import SwiftUI
import UIKit
import OSLog

/// Explicit opt-in measurement driver, shared by C and PV. No view/timer is
/// installed in ordinary launches. Does not equate CADisplayLink with display frames.
public struct HomeScrollMeasurementProbe: View {
    public init() {}
    public var body: some View {
        if HomeStartupTrace.enabled && ProcessInfo.processInfo.arguments.contains("--measure-home-scroll") {
            ScrollProbe().frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true)
        }
    }
}

private struct ScrollProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> MeasurementView { MeasurementView() }
    func updateUIView(_ view: MeasurementView, context: Context) {}
    static func dismantleUIView(_ view: MeasurementView, coordinator: ()) { view.stop(completed: false) }
}

@MainActor private final class MeasurementView: UIView {
    private static var consumed = false
    private static let log = Logger(subsystem: "com.example.streamlab.demo", category: "C4")
    private var warmup: Task<Void, Never>?
    private var link: CADisplayLink?
    private weak var scroll: UIScrollView?
    private var interval: HomeStartupTrace.Interval?
    private var start: CFTimeInterval?
    private var top: CGFloat = 0
    private var amplitude: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        NotificationCenter.default.addObserver(self, selector: #selector(background),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }
    convenience init() { self.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { stop(completed: false); return }
        guard warmup == nil, !Self.consumed else { return }
        HomeStartupTrace.event("C4ScrollWarmup")
        warmup = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(10)) } catch { return }
            self?.begin()
        }
    }

    private func begin() {
        guard window != nil, !Self.consumed, UIApplication.shared.applicationState == .active else { return }
        var parent = superview
        while let view = parent {
            if let candidate = view as? UIScrollView, candidate.bounds.height > 100,
               candidate.contentSize.height > candidate.bounds.height + 100 {
                scroll = candidate
                break
            }
            parent = view.superview
        }
        guard let scroll else {
            HomeStartupTrace.event("C4ScrollUnavailable")
            return
        }
        Self.consumed = true
        top = -scroll.adjustedContentInset.top
        amplitude = min(1000, scroll.contentSize.height - scroll.bounds.height
                        + scroll.adjustedContentInset.top + scroll.adjustedContentInset.bottom)
        guard amplitude > 0 else { return }
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: top), animated: false)
        Self.log.notice("controlled_scroll cycles=5 duration=30 amplitude_pt=\(Double(self.amplitude)) thermal=\(ProcessInfo.processInfo.thermalState.rawValue) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
        interval = HomeStartupTrace.begin("C4ControlledScroll")
        HomeStartupTrace.event("C4ScrollStart")
        let next = CADisplayLink(target: TickTarget(self), selector: #selector(TickTarget.tick(_:)))
        link = next
        next.add(to: .main, forMode: .common)
    }

    fileprivate func tick(_ link: CADisplayLink) {
        guard let scroll, window != nil else { stop(completed: false); return }
        guard !scroll.isDragging, !scroll.isTracking else { stop(completed: false); return }
        if start == nil { start = link.timestamp }
        let elapsed = link.timestamp - (start ?? link.timestamp)
        // Five triangular round trips, three seconds per leg. Long frames are
        // retained in Instruments, never discarded as measurement outliers.
        let phase = min(30, max(0, elapsed)).truncatingRemainder(dividingBy: 6) / 3
        let fraction = phase <= 1 ? phase : 2 - phase
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: top + amplitude * fraction), animated: false)
        if elapsed >= 30 { stop(completed: true) }
    }

    @objc private func background() { stop(completed: false) }
    fileprivate func stop(completed: Bool) {
        warmup?.cancel(); warmup = nil
        link?.invalidate(); link = nil
        if interval != nil {
            HomeStartupTrace.event(completed ? "C4ScrollEnd" : "C4ScrollCancelled")
            Self.log.notice("controlled_scroll completed=\(completed) thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
        }
        interval = nil
    }
}

@MainActor private final class TickTarget: NSObject {
    private weak var view: MeasurementView?
    init(_ view: MeasurementView) { self.view = view }
    @objc func tick(_ link: CADisplayLink) {
        guard let view else { link.invalidate(); return }
        view.tick(link)
    }
}
