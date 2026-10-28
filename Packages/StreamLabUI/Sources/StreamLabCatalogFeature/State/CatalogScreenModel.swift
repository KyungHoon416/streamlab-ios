import SwiftUI
import Combine
import StreamLabDesignSystem
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
    private var homeLoadSpan: HomeStartupTrace.Interval?
    private var homeReadyMarked = false
    // Home renders the same loading placeholder before and during its initial request.
    // Compare only what that screen displays, not request/lifecycle bookkeeping.
    private struct HomePresentation: Equatable {
        let hero: CatalogTitle?
        let rails: [ContentRail]
        let error: String?
        @MainActor init(_ store: CatalogStore) {
            hero = store.home?.hero
            rails = store.home?.rails ?? []
            error = store.errorMessage
        }
    }
    private var lastHomePresentation: HomePresentation?
    private var started = false
    private var visible = false
    private var active = false

    init(session: CatalogSession, screen: Screen) {
        let span = HomeStartupTrace.begin("ScreenModelInit")
        defer { withExtendedLifetime(span) {} }
        self.session = session
        self.screen = screen
        self.store = session.makeStore()
        if case .home = screen { lastHomePresentation = HomePresentation(store) }
        store.onChange = { [weak self] in self?.publishChange() }
    }

    private func publishChange() {
        if case .home = screen {
            let presentation = HomePresentation(store)
            if presentation != lastHomePresentation {
                lastHomePresentation = presentation
                HomeStartupTrace.measure("HomePublish") { revision &+= 1 }
            }
            if !store.loading {
                homeLoadSpan = nil
                if store.home != nil, !homeReadyMarked {
                    homeReadyMarked = true
                    HomeStartupTrace.event("HomeDataReady")
                }
            }
        } else { revision &+= 1 }
    }

    func appear(phase: ScenePhase) {
        visible = true
        setPhase(phase)
    }
    func disappear() {
        visible = false
        homeLoadSpan = nil
        HomeStartupTrace.event("ScreenDisappeared")
        store.suspend()
    }
    func setPhase(_ phase: ScenePhase) {
        active = phase == .active
        guard visible, active, session.isActive else {
            homeLoadSpan = nil
            store.suspend()
            return
        }
        if store.resume() != nil { return }
        guard !started else { publishChange(); return }
        started = true
        switch screen {
        case .home:
            homeLoadSpan = HomeStartupTrace.begin("HomeInitialLoadWait")
            store.loadHome()
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
