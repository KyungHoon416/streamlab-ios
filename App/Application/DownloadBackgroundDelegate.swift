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
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let shouldOpen = response.actionIdentifier == UNNotificationDefaultActionIdentifier
        let identifier = response.notification.request.identifier
        // UIKit's response completion also requires the main thread. An async
        // delegate bridge can finish off-main even after a MainActor.run block.
        DispatchQueue.main.async {
            if shouldOpen { DownloadNotificationNavigation.shared.receive(identifier) }
            completionHandler()
        }
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
    func scheduleSystemTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "StreamLab 알림 이동 검증"
        content.body = "실제 시스템 알림을 눌러 다운로드 목록 이동을 확인합니다."
        content.sound = .default
        let request = UNNotificationRequest(identifier: DownloadCompletionNotifier.prefix + UUID().uuidString,
            content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 20, repeats: false))
        do { try await UNUserNotificationCenter.current().add(request) }
        catch { assertionFailure("Unable to schedule test notification") }
    }
    func simulateTap() { receive(DownloadCompletionNotifier.prefix + UUID().uuidString) }
    #endif
}
