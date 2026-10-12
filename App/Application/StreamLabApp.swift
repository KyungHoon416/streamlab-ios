import SwiftUI

@main
@MainActor struct StreamLabApp: App {
    var body: some Scene {
        WindowGroup { AppRootView().preferredColorScheme(.dark) }
    }
}
