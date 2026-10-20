import Foundation

@MainActor public protocol DownloadNotificationBackend: AnyObject {
    func authorized() async -> Bool
    func post(identifier: String) async throws
    func remove(identifiers: [String])
    func identifiers() async -> [String]
}

/// Rechecks ownership after every asynchronous boundary, including an in-flight OS add.
@MainActor public final class DownloadCompletionNotifier {
    public static let prefix = "streamlab.download.complete."
    private let backend: any DownloadNotificationBackend
    private var epoch: UInt64 = 0
    private var cancelled: Set<UUID> = []
    private var known: Set<String> = []
    public init(backend: any DownloadNotificationBackend) { self.backend = backend }

    public func deliver(id: UUID, eligible: @MainActor () -> Bool) async {
        let ticket = epoch
        let identifier = Self.prefix + id.uuidString
        func valid() -> Bool { ticket == epoch && !cancelled.contains(id) && eligible() }
        guard valid(), await backend.authorized(), valid() else { return }
        known.insert(identifier)
        do { try await backend.post(identifier: identifier) }
        catch { backend.remove(identifiers: [identifier]); return }
        if !valid() { backend.remove(identifiers: [identifier]) }
    }

    public func cancel(id: UUID) {
        cancelled.insert(id)
        backend.remove(identifiers: [Self.prefix + id.uuidString])
    }

    /// Synchronous revocation must precede logout's first await.
    public func invalidateAll() {
        epoch &+= 1
        backend.remove(identifiers: Array(known))
    }

    public func removeAll() async {
        invalidateAll()
        let identifiers = await backend.identifiers()
        backend.remove(identifiers: identifiers.filter { $0.hasPrefix(Self.prefix) })
    }
}
