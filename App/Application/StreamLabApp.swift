import SwiftUI

@main
@MainActor struct StreamLabApp: App {
    @UIApplicationDelegateAdaptor(DownloadBackgroundDelegate.self) private var downloadDelegate
    var body: some Scene {
        WindowGroup { AppRootView().preferredColorScheme(.dark) }
    }
}
