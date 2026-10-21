import UIKit
import Combine
import UserNotifications
import StreamLabPresentation
import StreamLabCatalogFeature

/// System events only. SwiftUI still owns all scenes and screens.
@MainActor final class DownloadBackgroundDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let identifier = response.notification.request.identifier
        await MainActor.run { DownloadNotificationNavigation.shared.receive(identifier) }
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        guard identifier == OfflineDownloadStore.sessionIdentifier else { completionHandler(); return }
        OfflineDownloadStore.shared.handleBackgroundEvents(completion: completionHandler)
    }
}

/// Only a generic library destination is retained: never an account, profile or title.
@MainActor final class DownloadNotificationNavigation: ObservableObject {
    static let shared = DownloadNotificationNavigation()
    @Published private(set) var request: UUID?

    func receive(_ identifier: String) {
        guard identifier.hasPrefix(DownloadCompletionNotifier.prefix),
              UUID(uuidString: String(identifier.dropFirst(DownloadCompletionNotifier.prefix.count))) != nil else { return }
        request = UUID()
    }
    func clear() { request = nil }

    #if DEBUG
    func simulateTap() { receive(DownloadCompletionNotifier.prefix + UUID().uuidString) }
    #endif
}
