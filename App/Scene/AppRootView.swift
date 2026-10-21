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
        .onAppear { startupLog.notice("[Startup] SwiftUI root appeared") }
        .task { await account.prepare() }
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
                    session = CatalogSession(profile: profile, repository: repository)
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

@MainActor private struct CatalogTabs: View {
    let session: CatalogSession
    let onSwitchProfile: () -> Void
    let onLogout: () -> Void
    @ObservedObject private var notificationNavigation = DownloadNotificationNavigation.shared
    @State private var selectedTab = 0
    @State private var downloadsPath: [String] = []
    @State private var homePath: [String] = []
    @State private var searchPath: [String] = []
    @State private var confirmingLogout = false
    @Environment(\.scenePhase) private var phase

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView(session: session)
                    .navigationDestination(for: String.self) { id in
                        DetailView(id: id, session: session)
                    }
                    .toolbar { profileToolbar }
            }
            .tabItem { Label("홈", systemImage: "house.fill") }.tag(0)
            NavigationStack(path: $searchPath) {
                SearchView(session: session)
                    .navigationDestination(for: String.self) { id in
                        DetailView(id: id, session: session)
                    }
                    .toolbar { profileToolbar }
            }
            .tabItem { Label("검색", systemImage: "magnifyingglass") }.tag(1)
            NavigationStack(path: $downloadsPath) {
                DownloadsView(session: session)
                    .navigationDestination(for: String.self) { id in
                        DetailView(id: id, session: session)
                    }
                    .toolbar { profileToolbar }
            }
            .tabItem { Label("다운로드", systemImage: "arrow.down.circle") }.tag(2)
        }
        .onAppear {
            session.setSynchronizationActive(phase == .active)
            openRequestedDownloads()
        }
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

    private func openRequestedDownloads() {
        guard phase == .active, session.isActive, notificationNavigation.request != nil else { return }
        homePath = []
        searchPath = []
        downloadsPath = []
        selectedTab = 2
        notificationNavigation.clear()
    }

    @ToolbarContentBuilder private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("로그아웃") { confirmingLogout = true }
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
            Button(action: onSwitchProfile) { Label(session.profile.displayName, systemImage: session.profile.avatarSymbol) }
                .accessibilityLabel("프로필 변경")
                .accessibilityValue(session.profile.displayName)
                .accessibilityIdentifier("switch-profile")
        }
    }
}

