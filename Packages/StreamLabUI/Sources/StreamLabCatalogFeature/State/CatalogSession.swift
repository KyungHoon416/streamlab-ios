import Foundation
import StreamLabDomain
import StreamLabPresentation

/// A new identity for every selection, including reselecting the same profile.
@MainActor public final class CatalogSession {
    public let id = UUID()
    public let profile: ViewerProfile
    let repository: any CatalogRepository
    public private(set) var isActive = true
    private var stores: [WeakStore] = []

    private final class WeakStore {
        weak var value: CatalogStore?
        init(_ value: CatalogStore) { self.value = value }
    }

    public init(profile: ViewerProfile, repository: any CatalogRepository) {
        self.profile = profile
        self.repository = repository
    }

    func makeStore() -> CatalogStore {
        stores.removeAll { $0.value == nil }
        let store = CatalogStore(profile: profile, repository: repository)
        stores.append(WeakStore(store))
        return store
    }

    /// Called synchronously BEFORE replacing the SwiftUI subtree.
    public func invalidate() {
        isActive = false
        for reference in stores { reference.value?.invalidate() }
        stores.removeAll()
    }
}
