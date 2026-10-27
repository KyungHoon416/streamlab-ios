import Foundation
import OSLog
import SwiftUI
import UIKit

/// Opt-in diagnostics, with no profile IDs, URLs, titles or account data.
public enum HomeStartupTrace {
    public static let enabled = ProcessInfo.processInfo.arguments.contains("--trace-home-startup")
    private static let log = OSLog(subsystem: "com.example.streamlab.demo", category: .pointsOfInterest)

    /// Immutable, thread-safe lifetime token; each begin has a unique ID and one end.
    public final class Interval: @unchecked Sendable {
        private let name: StaticString
        private let id: OSSignpostID
        fileprivate init(_ name: StaticString) {
            self.name = name
            id = OSSignpostID(log: HomeStartupTrace.log)
            os_signpost(.begin, log: HomeStartupTrace.log, name: name, signpostID: id)
        }
        deinit { os_signpost(.end, log: HomeStartupTrace.log, name: name, signpostID: id) }
    }

    public static func begin(_ name: StaticString) -> Interval? {
        enabled ? Interval(name) : nil
    }
    public static func event(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.event, log: log, name: name)
    }
    public static func measure<T>(_ name: StaticString, _ operation: () throws -> T) rethrows -> T {
        let span = begin(name)
        defer { withExtendedLifetime(span) {} }
        return try operation()
    }
}

/// Marks this probe's first positive-size layout, NOT the end of all SwiftUI layout
/// or the first displayed frame. Use nearby Animation Hitches / CPU tracks for those.
public struct HomeStartupLayoutMarker: View {
    public init() {}
    public var body: some View {
        if HomeStartupTrace.enabled { LayoutProbe().allowsHitTesting(false).accessibilityHidden(true) }
    }
}

private struct LayoutProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ view: ProbeView, context: Context) {}
}
private final class ProbeView: UIView {
    private var marked = false
    init() { super.init(frame: .zero); isUserInteractionEnabled = false; isAccessibilityElement = false }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !marked, window != nil, bounds.width > 0, bounds.height > 0 else { return }
        marked = true
        HomeStartupTrace.event("HeroFirstLayout")
    }
}
