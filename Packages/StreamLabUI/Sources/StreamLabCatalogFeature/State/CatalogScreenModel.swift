import SwiftUI
import Combine
import StreamLabDomain
import StreamLabPresentation

/// SwiftUI observation adapter: Core remains Foundation-only and independently testable.
@MainActor final class CatalogScreenModel: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
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
        store.onChange = { [weak self] in self?.objectWillChange.send() }
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
        guard !started else { objectWillChange.send(); return }
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
