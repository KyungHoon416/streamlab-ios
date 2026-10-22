import SwiftUI
import UIKit

/// One modifier on the app root; no per-poster observers or growing notification registrations.
public struct ArtworkMemoryLifecycle: ViewModifier {
    @Environment(\.scenePhase) private var phase
    public init() {}
    public func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                Task { await ArtworkPipeline.shared.releaseMemory() }
            }
            .onChange(of: phase) { _, value in
                if value == .background {
                    Task { await ArtworkPipeline.shared.releaseMemory() }
                }
            }
    }
}
