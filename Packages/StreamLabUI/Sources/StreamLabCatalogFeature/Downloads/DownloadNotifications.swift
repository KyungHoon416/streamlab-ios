import Combine
import StreamLabPresentation
import UIKit
import UserNotifications

@MainActor final class DownloadNotifications: ObservableObject, DownloadNotificationBackend {
    static let shared = DownloadNotifications()
    @Published private(set) var permission: UNAuthorizationStatus = .notDetermined
    @Published private(set) var requesting = false
    @Published private(set) var errorMessage: String?
    private let center = UNUserNotificationCenter.current()

    var isInBackground: Bool { UIApplication.shared.applicationState == .background }
    func openSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
    }
    func refresh() async { permission = await center.notificationSettings().authorizationStatus }
    func request() async {
        guard !requesting else { return }
        requesting = true
        defer { requesting = false }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            errorMessage = nil
        } catch { errorMessage = "알림 권한을 확인하지 못했습니다. 다시 시도해 주세요." }
        await refresh()
    }
    func authorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }
    func post(identifier: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "다운로드 완료"
        content.body = "다운로드 탭에서 저장한 HLS 샘플을 재생할 수 있습니다."
        content.sound = .default
        // A brief pending interval also permits cancellation of an in-flight add.
        let request = UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false))
        try await center.add(request)
    }
    func remove(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    func identifiers() async -> [String] {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        let delivered = await center.deliveredNotifications().map { $0.request.identifier }
        return pending + delivered
    }
}
