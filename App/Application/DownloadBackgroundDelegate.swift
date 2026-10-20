import UIKit
import StreamLabCatalogFeature

/// Background transfer completion only. SwiftUI still owns all scenes and screens.
@MainActor final class DownloadBackgroundDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == OfflineDownloadStore.sessionIdentifier else { completionHandler(); return }
        OfflineDownloadStore.shared.handleBackgroundEvents(completion: completionHandler)
    }
}
