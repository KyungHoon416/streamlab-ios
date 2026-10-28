import SwiftUI
import OSLog
import StreamLabDomain
import StreamLabCatalogData
import StreamLabCatalogFeature
import StreamLabProfileFeature
import StreamLabDesignSystem

@MainActor struct AppRootView: View {
    @State private var session: CatalogSession?
    @StateObject private var account = CatalogAccount()
    private let repository: MockCatalogRepository
    private let startupLog = Logger(subsystem: "com.example.streamlab.demo", category: "Startup")

    init() {
        let span = HomeStartupTrace.begin("RootInit")
        defer { withExtendedLifetime(span) {} }
        #if DEBUG
        repository = MockCatalogRepository(responseDelay: ProcessInfo.processInfo.arguments.contains("--ui-test-slow-catalog") ? .seconds(4) : .milliseconds(120))
        #else
        repository = MockCatalogRepository()
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            NetworkConnectionBanner(showOffline: !account.isSignedOut)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(StreamLabTheme.accent)
        .modifier(StreamLabMotionPolicy())
        .modifier(ArtworkMemoryLifecycle())
        .progressViewStyle(StreamLabProgressStyle())
        .onAppear {
            HomeStartupTrace.event("RootAppeared")
            startupLog.notice("[Startup] SwiftUI root appeared")
            startupLog.notice("\(HomeRenderExperiment.current.description, privacy: .public)")
        }
        .task {
            let span = HomeStartupTrace.begin("AccountPrepare")
            defer { withExtendedLifetime(span) {} }
            await account.prepare()
        }
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("--ui-test-download-notification-launch") {
                DownloadNotificationNavigation.shared.simulateTap()
            }
        }
        #endif
    }

    private var content: some View {
        Group {
            if account.isRestoring {
                ProgressView("데모 계정을 확인하고 있어요")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(StreamLabTheme.background)
                    .accessibilityIdentifier("account-restoring")
            } else if account.isSignedOut {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 20) {
                            Text("StreamLab 데모")
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                            Text("서버 연결 없는 과제용 데모입니다.\n데모 시작을 누르면 이 기기에 로그인 상태가 저장됩니다.")
                                .accessibilityIdentifier("demo-sign-in-description")
                            if account.isBusy { ProgressView("데모 계정을 준비하고 있어요") }
                            if let error = account.errorMessage {
                                Text(error).foregroundStyle(.secondary)
                                    .accessibilityIdentifier("logout-error")
                            }
                            Button("데모 시작") { Task { await account.signInDemo() } }
                                .buttonStyle(StreamLabButtonStyle())
                                .disabled(account.isBusy)
                                .accessibilityIdentifier("demo-sign-in")
                        }
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 560)
                        .padding(24)
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                    .accessibilityIdentifier("demo-sign-in-scroll")
                }
                .background(StreamLabTheme.background)
            } else if let session {
                CatalogTabs(session: session, onSwitchProfile: switchProfile, onLogout: logout)
                    .id(session.id)
            } else {
                ProfileSelectionView { profile in
                    session = HomeStartupTrace.measure("ProfileSelection") {
                        CatalogSession(profile: profile, repository: repository)
                    }
                }

            }
        }
    }

    private func logout() {
        DownloadNotificationNavigation.shared.clear()
        let previous = session
        Task {
            await account.logout(session: previous)
            session = nil
        }
    }

    private func switchProfile() {
        session?.invalidate()
        session = nil
    }
}

/// Process-local diagnostics only; no saved setting can affect normal launches.
private enum StartupChromeExperiment: String {
    case baseline, noToolbar = "no-toolbar", noTabs = "no-tabs"
    static let current: Self = {
        guard HomeStartupTrace.enabled else { return .baseline }
        let values = ProcessInfo.processInfo.arguments.filter { $0.hasPrefix("--startup-chrome=") }
        guard values.count == 1, let raw = values.first?.split(separator: "=", maxSplits: 1).last,
              let mode = Self(rawValue: String(raw)) else { return .baseline }
        return mode
    }()
    func mark() {
        switch self {
        case .baseline: HomeStartupTrace.event("StartupChromeBaseline")
        case .noToolbar: HomeStartupTrace.event("StartupChromeNoToolbar")
        case .noTabs: HomeStartupTrace.event("StartupChromeNoTabs")
        }
    }
}

@MainActor private struct CatalogTabs: View {
    let session: CatalogSession
    let onSwitchProfile: () -> Void
    let onLogout: () -> Void
    @ObservedObject private var notificationNavigation = DownloadNotificationNavigation.shared
    @State private var selectedTab = 0
    // Build each navigation subtree on first selection, then keep its state.
    @State private var visitedTabs: Set<Int> = [0]
    @State private var downloadsPath: [String] = []
    @State private var homePath: [String] = []
    @State private var searchPath: [String] = []
    @State private var confirmingLogout = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        let span = HomeStartupTrace.begin("CatalogTabsBodyValue")
        defer { withExtendedLifetime(span) {} }
        return Group {
            if StartupChromeExperiment.current == .noTabs {
                // Remove the tab container, retain the same navigation/content/toolbar.
                tabRoot(CatalogTabKind(rawValue: selectedTab) ?? .home)
            } else {
                TabView(selection: $selectedTab) {
                    // Declare tab metadata independently of each screen's view tree.
                    // Keep the content roots and per-tab paths stable across selections.
                    Tab(CatalogTabKind.home.title, systemImage: CatalogTabKind.home.symbol,
                        value: CatalogTabKind.home.rawValue) { tabRoot(.home) }
                    Tab(CatalogTabKind.search.title, systemImage: CatalogTabKind.search.symbol,
                        value: CatalogTabKind.search.rawValue) { tabRoot(.search) }
                    Tab(CatalogTabKind.downloads.title, systemImage: CatalogTabKind.downloads.symbol,
                        value: CatalogTabKind.downloads.rawValue) { tabRoot(.downloads) }
                }
            }
        }
        .onAppear {
            StartupChromeExperiment.current.mark()
            if StartupChromeExperiment.current != .noTabs {
                HomeStartupTrace.event("StartupTabsExplicit")
            }
            session.setSynchronizationActive(phase == .active)
            openRequestedDownloads()
        }
        .onChange(of: selectedTab) { _, tab in visitedTabs.insert(tab) }
        .onChange(of: notificationNavigation.request) { _, _ in openRequestedDownloads() }
        .onChange(of: phase) { _, value in
            session.setSynchronizationActive(value == .active)
            if value == .active { openRequestedDownloads() }
            #if DEBUG
            if value == .background && ProcessInfo.processInfo.arguments.contains("--ui-test-download-notification-background") {
                notificationNavigation.simulateTap()
            }
            #endif
        }
        .confirmationDialog("로그아웃하면 이 기기의 모든 프로필 기록이 삭제됩니다.",
                            isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive, action: onLogout)
                .accessibilityIdentifier("confirm-logout")
            Button("취소", role: .cancel) {}
        }
    }

    private func tabRoot(_ tab: CatalogTabKind) -> some View {
        CatalogTabRoot(tab: tab, session: session,
                       isLoaded: selectedTab == tab.rawValue || visitedTabs.contains(tab.rawValue),
                       path: path(for: tab), confirmingLogout: $confirmingLogout,
                       onSwitchProfile: onSwitchProfile)
    }

    private func openRequestedDownloads() {
        guard phase == .active, session.isActive, notificationNavigation.request != nil else { return }
        homePath = []
        searchPath = []
        downloadsPath = []
        selectedTab = 2
        notificationNavigation.clear()
    }

    private func path(for tab: CatalogTabKind) -> Binding<[String]> {
        switch tab {
        case .home: $homePath
        case .search: $searchPath
        case .downloads: $downloadsPath
        }
    }
}

private enum CatalogTabKind: Int {
    case home, search, downloads
    var title: String {
        switch self { case .home: "홈"; case .search: "검색"; case .downloads: "다운로드" }
    }
    var symbol: String {
        switch self { case .home: "house.fill"; case .search: "magnifyingglass"; case .downloads: "arrow.down.circle" }
    }
}

/// All three tabs share one navigation/toolbar type while retaining independent paths.
@MainActor private struct CatalogTabRoot: View {
    let tab: CatalogTabKind
    let session: CatalogSession
    let isLoaded: Bool
    @Binding var path: [String]
    @Binding var confirmingLogout: Bool
    let onSwitchProfile: () -> Void

    var body: some View {
        Group {
            if isLoaded {
                NavigationStack(path: $path) {
                    screen
                        .navigationDestination(for: String.self) { id in
                            DetailView(id: id, session: session)
                        }
                        .toolbar {
                            if StartupChromeExperiment.current != .noToolbar {
                                CatalogProfileToolbar(profile: session.profile,
                                                      confirmingLogout: $confirmingLogout,
                                                      onSwitchProfile: onSwitchProfile)
                            }
                        }
                }
            } else {
                // A concrete placeholder keeps unvisited tabs visible in TabView.
                Color.clear
            }
        }
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .home: HomeView(session: session)
        case .search: SearchView(session: session)
        case .downloads: DownloadsView(session: session)
        }
    }
}

@MainActor private struct CatalogProfileToolbar: ToolbarContent {
    let profile: ViewerProfile
    @Binding var confirmingLogout: Bool
    let onSwitchProfile: () -> Void
    private let notificationNavigation = DownloadNotificationNavigation.shared

    @ToolbarContentBuilder var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { confirmingLogout = true } label: {
                Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
            }
                .accessibilityLabel("로그아웃")
                .accessibilityIdentifier("account-logout")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-system-notification") {
            ToolbarItem(placement: .topBarTrailing) {
                Button("알림 예약") { Task { await notificationNavigation.scheduleSystemTestNotification() } }
                    .accessibilityIdentifier("download-system-notification-test")
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-test-download-notification-tap") {
            ToolbarItem(placement: .topBarTrailing) {
                Button("알림 검증") { notificationNavigation.simulateTap() }
                    .accessibilityIdentifier("download-notification-test-tap")
            }
        }
        #endif
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSwitchProfile) { Label(profile.displayName, systemImage: profile.avatarSymbol) }
                .accessibilityLabel("프로필 변경")
                .accessibilityValue(profile.displayName)
                .accessibilityIdentifier("switch-profile")
        }
    }
}

