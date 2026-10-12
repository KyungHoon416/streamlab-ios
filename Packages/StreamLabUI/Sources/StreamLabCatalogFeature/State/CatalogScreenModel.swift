import SwiftUI
import Combine
import StreamLabDomain
import StreamLabPresentation

/// SwiftUI observation adapter: Core remains Foundation-only and independently testable.
@MainActor final class CatalogScreenModel: ObservableObject {
    // Use Combine’s synthesized publisher; an explicit actor-isolated publisher
    // cannot satisfy ObservableObject’s nonisolated requirement in Swift 6.
    @Published private var revision: UInt64 = 0
    enum Screen { case home, search, detail(String) }
    let store: CatalogStore
    private let session: CatalogSession
    private let screen: Screen
    private var started = false
    private var visible = false
    private var active = false

    init(session: CatalogSession, screen: Screen) {
        self.session = session
        self.screen = screen
        self.store = session.makeStore()
        store.onChange = { [weak self] in self?.publishChange() }
    }

    private func publishChange() {
        revision &+= 1
    }

    func appear(phase: ScenePhase) {
        visible = true
        setPhase(phase)
    }
    func disappear() {
        visible = false
        store.suspend()
    }
    func setPhase(_ phase: ScenePhase) {
        active = phase == .active
        guard visible, active, session.isActive else {
            store.suspend()
            return
        }
        if store.resume() != nil { return }
        guard !started else { publishChange(); return }
        started = true
        switch screen {
        case .home: store.loadHome()
        case .search: store.search("", debounce: .zero)
        case .detail(let id): store.loadDetail(id: id)
        }
    }
    func search(_ query: String) {
        guard visible, session.isActive else { return }
        store.search(query)
        if !active { store.suspend() }
    }
    func loadNext() {
        guard visible, active, session.isActive else { return }
        store.loadNext()
    }
    func retry() {
        guard visible, active, session.isActive else { return }
        store.retry()
    }
}
