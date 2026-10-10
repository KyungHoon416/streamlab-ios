import UIKit
import StreamLabDomain
import StreamLabCatalogData

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let repository = MockCatalogRepository()
    private let storyboard = UIStoryboard(name: "Main", bundle: nil)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: scene)
        showProfiles()
        window?.makeKeyAndVisible()
    }

    private func showProfiles() {
        let screen = storyboard.instantiateViewController(withIdentifier: "ProfileViewController") as! ProfileViewController
        screen.onSelect = { [weak self] profile in self?.openCatalog(profile) }
        window?.rootViewController = screen
    }

    private func openCatalog(_ profile: ViewerProfile) {
        let home = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as! HomeViewController
        home.configure(profile: profile, repository: repository)
        home.onSwitch = { [weak self] in self?.showProfiles() }
        let search = storyboard.instantiateViewController(withIdentifier: "SearchViewController") as! SearchViewController
        search.configure(profile: profile, repository: repository)
        let homeNav = UINavigationController(rootViewController: home)
        let searchNav = UINavigationController(rootViewController: search)
        homeNav.tabBarItem = UITabBarItem(title: "홈", image: UIImage(systemName: "house.fill"), tag: 0)
        searchNav.tabBarItem = UITabBarItem(title: "검색", image: UIImage(systemName: "magnifyingglass"), tag: 1)
        let tabs = UITabBarController()
        tabs.viewControllers = [homeNav, searchNav]
        tabs.tabBar.tintColor = .systemRed
        tabs.overrideUserInterfaceStyle = .dark
        window?.rootViewController = tabs
    }
}
