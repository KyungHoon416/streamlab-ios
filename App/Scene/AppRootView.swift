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
        Group {
            if account.isSignedOut {
                VStack(spacing: 20) {
                    Text("StreamLab 데모").font(.largeTitle.bold())
                    Text("데모 시작을 눌러 프로필을 선택하세요.")
                        .multilineTextAlignment(.center)
                    if account.isBusy { ProgressView("로컬 기록을 정리하고 있어요") }
                    if let error = account.errorMessage {
                        Text(error).foregroundStyle(.secondary)
                            .accessibilityIdentifier("logout-error")
                    }
                    Button("데모 시작") { Task { await account.signInDemo() } }
                        .buttonStyle(StreamLabButtonStyle())
                        .disabled(account.isBusy)
                        .accessibilityIdentifier("demo-sign-in")
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(StreamLabTheme.background)
            } else if let session {
                CatalogTabs(session: session, onSwitchProfile: switchProfile, onLogout: logout)
                    .id(session.id)
            } else {
                ProfileSelectionView { profile in
                    session = CatalogSession(profile: profile, repository: repository)
                }
                .safeAreaInset(edge: .top, spacing: 0) { ProfileNetworkBanner() }
            }
        }
        .tint(StreamLabTheme.accent)
        .onAppear { startupLog.notice("[Startup] SwiftUI root appeared") }
        .task {
            if account.isSignedOut { await account.logout(session: nil) }
        }
    }

    private func logout() {
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
    @State private var confirmingLogout = false

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
        .confirmationDialog("로그아웃하면 이 기기의 모든 프로필 기록이 삭제됩니다.",
                            isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive, action: onLogout)
                .accessibilityIdentifier("confirm-logout")
            Button("취소", role: .cancel) {}
        }
    }

    @ToolbarContentBuilder private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("로그아웃") { confirmingLogout = true }
                .accessibilityIdentifier("account-logout")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: onSwitchProfile) { Label(session.profile.displayName, systemImage: session.profile.avatarSymbol) }
                .accessibilityLabel("프로필 변경")
                .accessibilityValue(session.profile.displayName)
                .accessibilityIdentifier("switch-profile")
        }
    }
}

