import SwiftUI
import OSLog
import StreamLabDomain
import StreamLabCatalogData
import StreamLabCatalogFeature
import StreamLabProfileFeature
import StreamLabDesignSystem

@MainActor struct AppRootView: View {
    @StateObject private var network = NetworkConnectionStatus()
    @Environment(\.scenePhase) private var phase
    @State private var session: CatalogSession?
    private let repository: MockCatalogRepository
    private let startupLog = Logger(subsystem: "com.example.streamlab.demo", category: "Startup")

    init() {
        #if DEBUG
        repository = MockCatalogRepository(responseDelay: ProcessInfo.processInfo.arguments.contains("--ui-test-slow-catalog") ? .seconds(4) : .milliseconds(120))
        #else
        repository = MockCatalogRepository()
        #endif
    }

    var body: some View {
        Group {
            if let session {
                CatalogTabs(session: session, onSwitchProfile: switchProfile)
                    .id(session.id)
            } else {
                ProfileSelectionView { profile in
                    session = CatalogSession(profile: profile, repository: repository)
                }
                .safeAreaInset(edge: .top, spacing: 0) { NetworkConnectionBanner() }
            }
        }
        .environmentObject(network)
        .task(id: phase == .active) { await network.observe(active: phase == .active) }
        .tint(StreamLabTheme.accent)
        .onAppear { startupLog.notice("[Startup] SwiftUI root appeared") }
    }

    private func switchProfile() {
        session?.invalidate()
        session = nil
    }
}

@MainActor private struct CatalogTabs: View {
    let session: CatalogSession
    let onSwitchProfile: () -> Void

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(session: session)
                    .navigationDestination(for: String.self) { id in
                        DetailView(id: id, session: session)
                    }
                    .toolbar { profileToolbar }
            }
            .tabItem { Label("홈", systemImage: "house.fill") }
            NavigationStack {
                SearchView(session: session)
                    .navigationDestination(for: String.self) { id in
                        DetailView(id: id, session: session)
                    }
                    .toolbar { profileToolbar }
            }
            .tabItem { Label("검색", systemImage: "magnifyingglass") }
        }
        .safeAreaInset(edge: .top, spacing: 0) { NetworkConnectionBanner() }
    }

    @ToolbarContentBuilder private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSwitchProfile) { Label(session.profile.displayName, systemImage: session.profile.avatarSymbol) }
                .accessibilityLabel("프로필 변경")
                .accessibilityValue(session.profile.displayName)
                .accessibilityIdentifier("switch-profile")
        }
    }
}

