import UIKit
import OSLog
import StreamLabDomain
import StreamLabCatalogData
import StreamLabPresentation
import StreamLabDesignSystem
import StreamLabProfileFeature
import StreamLabCatalogFeature

@MainActor final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let startupLog = Logger(subsystem: "com.example.streamlab.demo", category: "Startup")
    private let repository: MockCatalogRepository = {
        #if DEBUG
        // UI tests opt in; normal app launches keep the existing response delay.
        if ProcessInfo.processInfo.arguments.contains("--ui-test-slow-catalog") {
            return MockCatalogRepository(responseDelay: .seconds(2))
        }
        #endif
        return MockCatalogRepository()
    }()
    private var stores: [CatalogStore] = []

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        startupLog.notice("[Startup] scene will connect")
        guard let windowScene = scene as? UIWindowScene else {
            startupLog.error("[Startup] expected UIWindowScene")
            return
        }
        connectWindow(to: windowScene)
    }

    private func connectWindow(to windowScene: UIWindowScene) {
        let appWindow = window ?? UIWindow(windowScene: windowScene)
        appWindow.frame = windowScene.coordinateSpace.bounds
        appWindow.overrideUserInterfaceStyle = .dark
        appWindow.tintColor = StreamLabTheme.accent
        window = appWindow
        if appWindow.rootViewController == nil { showProfiles() }
        appWindow.makeKeyAndVisible()
        startupLog.notice("[Startup] window is visible")
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Recreate only a missing root; preserve navigation on normal foregrounding.
        guard window?.rootViewController == nil, let windowScene = scene as? UIWindowScene else { return }
        startupLog.notice("[Startup] reconnecting scene window")
        connectWindow(to: windowScene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        stores.forEach { $0.invalidate(); $0.onChange = nil }
        window?.rootViewController = nil
        window = nil
        stores = []
    }
    private func showProfiles() {
        stores.forEach { $0.invalidate(); $0.onChange = nil }
        stores = []
        startupLog.notice("[Startup] loading Profile.storyboard")
        let controller = ProfileViewController.instantiate()
        controller.onSelect = { [weak self] in self?.showCatalog(profile: $0) }
        controller.loadViewIfNeeded()
        window?.rootViewController = controller
        startupLog.notice("[Startup] profile root installed")
    }
    private func showCatalog(profile: ViewerProfile) {
        let home = HomeViewController.instantiate()
        let search = SearchViewController.instantiate()
        home.store = makeStore(profile)
        search.store = makeStore(profile)
        let homeNav = navigation(home)
        let searchNav = navigation(search)
        homeNav.tabBarItem = UITabBarItem(title: "홈", image: UIImage(systemName: "house.fill"), tag: 0)
        searchNav.tabBarItem = UITabBarItem(title: "검색", image: UIImage(systemName: "magnifyingglass"), tag: 1)
        for screen in [home as UIViewController, search as UIViewController] {
            screen.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "프로필 변경", image: UIImage(systemName: "person.crop.circle"), primaryAction: UIAction { [weak self] _ in self?.showProfiles() })
            screen.navigationItem.rightBarButtonItem?.accessibilityIdentifier = "switch-profile"
        }
        home.onSelect = { [weak self, weak homeNav] id in self?.showDetail(id, profile: profile, navigation: homeNav) }
        search.onSelect = { [weak self, weak searchNav] id in self?.showDetail(id, profile: profile, navigation: searchNav) }
        let tabs = UITabBarController()
        tabs.viewControllers = [homeNav, searchNav]
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        tabs.tabBar.standardAppearance = appearance
        tabs.tabBar.scrollEdgeAppearance = appearance
        window?.rootViewController = tabs
    }
    private func makeStore(_ profile: ViewerProfile) -> CatalogStore {
        let store = CatalogStore(profile: profile, repository: repository)
        stores.append(store)
        return store
    }
    private func showDetail(_ id: String, profile: ViewerProfile, navigation: UINavigationController?) {
        guard let navigation else { return }
        let detail = DetailViewController.instantiate()
        // Detail owns its store; avoid retaining every popped detail in the coordinator.
        detail.store = CatalogStore(profile: profile, repository: repository)
        detail.titleID = id
        navigation.pushViewController(detail, animated: !UIAccessibility.isReduceMotionEnabled)
    }
    private func navigation(_ root: UIViewController) -> UINavigationController {
        let nav = UINavigationController(rootViewController: root)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        return nav
    }
}
