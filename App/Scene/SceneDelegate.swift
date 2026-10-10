import UIKit
import StreamLabDomain
import StreamLabCatalogData
import StreamLabPresentation
import StreamLabDesignSystem
import StreamLabProfileFeature
import StreamLabCatalogFeature

@MainActor final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let repository = MockCatalogRepository()
    private var stores: [CatalogStore] = []

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.tintColor = StreamLabTheme.accent
        self.window = window
        showProfiles()
        window.makeKeyAndVisible()
    }
    func sceneDidDisconnect(_ scene: UIScene) {
        stores.forEach { $0.invalidate() }
        window?.rootViewController = nil
        stores = []
    }
    private func showProfiles() {
        stores.forEach { $0.invalidate(); $0.onChange = nil }
        stores = []
        let controller = ProfileViewController.instantiate()
        controller.onSelect = { [weak self] in self?.showCatalog(profile: $0) }
        window?.rootViewController = controller
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
