import Combine
import Foundation
import StreamLabDomain

/// Small, local-only saved catalog snapshots. Detail/playback still reauthorize via Repository.
@MainActor final class MyListStore: ObservableObject {
    @Published private(set) var items: [CatalogTitle] = []
    private let profile: ViewerProfile
    private let defaults: UserDefaults
    private let key: String
    private var active = true

    init(profile: ViewerProfile, defaults: UserDefaults = .standard) {
        self.profile = profile
        self.defaults = defaults
        key = "streamlab.my-list.v1.\(profile.id)"
        items = read()
    }

    func contains(_ title: CatalogTitle) -> Bool { items.contains { $0.id == title.id } }

    func toggle(_ title: CatalogTitle) {
        guard active, title.canView(in: profile) else { return }
        var updated = read()
        if updated.contains(where: { $0.id == title.id }) {
            updated.removeAll { $0.id == title.id }
        } else {
            updated.insert(title, at: 0)
        }
        guard let data = try? JSONEncoder().encode(updated) else { return }
        defaults.set(data, forKey: key)
        items = updated
    }

    func refresh() {
        guard active else { return }
        items = read()
    }

    func invalidate() {
        active = false
        items = []
    }

    private func read() -> [CatalogTitle] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CatalogTitle].self, from: data) else { return [] }
        var seen: Set<String> = []
        return decoded.filter { $0.canView(in: profile) && seen.insert($0.id).inserted }
    }
}
