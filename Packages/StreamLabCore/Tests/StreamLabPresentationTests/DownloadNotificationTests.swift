import Foundation
import Testing
@testable import StreamLabPresentation
import StreamLabDomain

@MainActor private final class NotificationBackendStub: DownloadNotificationBackend {
    var allowed = true
    var posted: [String] = []
    var visible: Set<String> = []
    var onAuthorization: (() -> Void)?
    var onPost: (() -> Void)?
    func authorized() async -> Bool { onAuthorization?(); return allowed }
    func post(identifier: String) async throws {
        onPost?() // Simulates revocation while the OS add is suspended.
        posted.append(identifier); visible.insert(identifier)
    }
    func remove(identifiers: [String]) { visible.subtract(identifiers) }
    func identifiers() async -> [String] { Array(visible) }
}

@Suite("Download completion notifications and network notices") @MainActor
struct DownloadNotificationTests {
    @Test func eligibleCompletionPosts() async {
        let backend = NotificationBackendStub(), id = UUID()
        let notifier = DownloadCompletionNotifier(backend: backend)
        await notifier.deliver(id: id) { true }
        #expect(backend.visible == [DownloadCompletionNotifier.prefix + id.uuidString])
    }
    @Test func foregroundOrFailedRecordNeverPosts() async {
        let backend = NotificationBackendStub()
        await DownloadCompletionNotifier(backend: backend).deliver(id: UUID()) { false }
        #expect(backend.posted.isEmpty)
    }
    @Test func deniedPermissionNeverPosts() async {
        let backend = NotificationBackendStub(); backend.allowed = false
        await DownloadCompletionNotifier(backend: backend).deliver(id: UUID()) { true }
        #expect(backend.posted.isEmpty)
    }
    @Test func cancellationDuringPermissionLookupNeverPosts() async {
        let backend = NotificationBackendStub(), id = UUID()
        let notifier = DownloadCompletionNotifier(backend: backend)
        backend.onAuthorization = { notifier.cancel(id: id) }
        await notifier.deliver(id: id) { true }
        #expect(backend.posted.isEmpty)
    }
    @Test func logoutDuringOSAddRemovesLateNotification() async {
        let backend = NotificationBackendStub()
        let notifier = DownloadCompletionNotifier(backend: backend)
        backend.onPost = { notifier.invalidateAll() }
        await notifier.deliver(id: UUID()) { true }
        #expect(backend.posted.count == 1)
        #expect(backend.visible.isEmpty)
    }
    @Test func cancelDuringOSAddRemovesLateNotification() async {
        let backend = NotificationBackendStub(), id = UUID()
        let notifier = DownloadCompletionNotifier(backend: backend)
        backend.onPost = { notifier.cancel(id: id) }
        await notifier.deliver(id: id) { true }
        #expect(backend.visible.isEmpty)
    }
    @Test func logoutPurgesPersistedOwnedNotificationsOnly() async {
        let backend = NotificationBackendStub()
        backend.visible = [DownloadCompletionNotifier.prefix + UUID().uuidString, "unrelated"]
        await DownloadCompletionNotifier(backend: backend).removeAll()
        #expect(backend.visible == ["unrelated"])
    }
    @Test func initialOnlineDoesNotShowRecoveryAndDuplicatesDoNotReopen() {
        var notice = NetworkConnectionNotice()
        notice.receive(available: true)
        #expect(notice.display == .none)
        notice.receive(available: false)
        #expect(notice.display == .offline)
        notice.receive(available: true)
        #expect(notice.display == .restored)
        notice.dismissRestored()
        notice.receive(available: true)
        #expect(notice.display == .none)
        notice.receive(available: false)
        notice.dismissRestored()
        #expect(notice.display == .offline)
        notice.receive(available: true)
        #expect(notice.display == .restored)
    }
}
