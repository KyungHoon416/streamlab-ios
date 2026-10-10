import UIKit
import OSLog

@main @MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private let startupLog = Logger(subsystem: "com.example.streamlab.demo", category: "Startup")

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        startupLog.notice("[Startup] application launched")
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        startupLog.notice("[Startup] application requested scene configuration")
        let configuration = UISceneConfiguration(name: "StreamLab", sessionRole: connectingSceneSession.role)
        configuration.sceneClass = UIWindowScene.self
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}
