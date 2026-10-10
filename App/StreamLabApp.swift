import SwiftUI
import StreamLabDomain
import StreamLabCatalogData
import StreamLabCatalogFeature
import StreamLabProfileFeature
import StreamLabDesignSystem

@main
struct StreamLabApp: App {
    @State private var activeProfile: ViewerProfile?
    // Reusable actor shared by feature views, never by global mutable singleton.
    private let catalog = MockCatalogRepository()

    var body: some Scene {
        WindowGroup {
            Group {
                if let activeProfile {
                    TabView {
                        HomeView(profile: activeProfile, repository: catalog) {
                            self.activeProfile = nil
                        }
                        .tabItem { Label("홈", systemImage: "house.fill") }

                        SearchView(profile: activeProfile, repository: catalog)
                            .tabItem { Label("검색", systemImage: "magnifyingglass") }
                    }
                    .id(activeProfile.id)
                } else {
                    ProfileSelectionView { activeProfile = $0 }
                }
            }
            .preferredColorScheme(.dark)
            .tint(StreamLabTheme.accent)
        }
    }
}
