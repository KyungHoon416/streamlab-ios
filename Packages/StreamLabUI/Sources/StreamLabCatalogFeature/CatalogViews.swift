import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

public struct HomeView: View {
    public let profile: ViewerProfile
    public let onSwitchProfile: () -> Void
    @State private var model: HomeViewModel

    public init(profile: ViewerProfile, repository: any CatalogRepository, onSwitchProfile: @escaping () -> Void) {
        self.profile = profile
        self.onSwitchProfile = onSwitchProfile
        _model = State(initialValue: HomeViewModel(repository: repository))
    }

    public var body: some View {
        NavigationStack {
            Group {
                if let snapshot = model.snapshot {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            hero(snapshot.hero)
                            if !snapshot.continueWatching.isEmpty {
                                continueWatching(snapshot.continueWatching)
                            }
                            ForEach(snapshot.rails) { rail in
                                railView(rail)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                } else if model.loading {
                    ProgressView("콘텐츠를 불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("콘텐츠를 불러올 수 없습니다", systemImage: "wifi.exclamationmark", description: Text(model.errorMessage ?? "잠시 후 다시 시도해 주세요."))
                }
            }
            .background(StreamLabTheme.background)
            .navigationTitle("STREAMLAB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSwitchProfile) {
                        Label("프로필 변경", systemImage: profile.avatarSymbol)
                    }
                }
            }
            .navigationDestination(for: CatalogTitle.self) { title in
                DetailView(title: title, profile: profile)
            }
        }
        .task(id: profile.id) { await model.load(profile: profile) }
    }

    private func hero(_ title: CatalogTitle) -> some View {
        NavigationLink(value: title) {
            ZStack(alignment: .bottomLeading) {
                PosterArtwork(title: title, showName: false)
                LinearGradient(colors: [.clear, .black.opacity(0.86)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 10) {
                    Text("STREAMLAB ORIGINAL")
                        .font(.caption.bold()).tracking(2)
                    Text(title.name)
                        .font(.largeTitle.bold())
                    Text(title.genre + "  •  " + title.typeLabel + "  •  " + title.rating.rawValue)
                        .font(.subheadline)
                    Label("작품 살펴보기", systemImage: "info.circle.fill")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 17).padding(.vertical, 11)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.black)
                }
                .foregroundStyle(.white)
                .padding(22)
            }
            .frame(height: 375)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func railView(_ rail: ContentRail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(rail.title).font(.title3.bold()).padding(.horizontal, 16)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(rail.items) { title in
                        NavigationLink(value: title) {
                            PosterCard(title: title)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func continueWatching(_ items: [ContinueWatchingItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(profile.displayName)님의 계속 시청")
                .font(.title3.bold()).padding(.horizontal, 16)
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: item.title) {
                            VStack(alignment: .leading, spacing: 6) {
                                PosterArtwork(title: item.title)
                                    .frame(width: 190, height: 116)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                ProgressView(value: item.fraction)
                                    .tint(StreamLabTheme.accent)
                                Text(item.title.name).font(.caption).lineLimit(1)
                            }
                            .frame(width: 190)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
        }
    }
}

public struct SearchView: View {
    public let profile: ViewerProfile
    @State private var query = ""
    @State private var model: SearchViewModel

    public init(profile: ViewerProfile, repository: any CatalogRepository) {
        self.profile = profile
        _model = State(initialValue: SearchViewModel(repository: repository))
    }

    public var body: some View {
        NavigationStack {
            List {
                if model.isLoading && model.items.isEmpty {
                    ProgressView("검색 중...")
                }
                if let error = model.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
                ForEach(model.items) { title in
                    NavigationLink(value: title) {
                        HStack(spacing: 14) {
                            PosterArtwork(title: title)
                                .frame(width: 65, height: 86)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title.name).font(.headline)
                                Text("\(title.year) · \(title.genre) · \(title.rating.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(title.typeLabel).font(.caption2)
                            }
                        }
                    }
                }
                if model.nextCursor != nil {
                    Button(model.isLoading ? "불러오는 중..." : "다음 결과 불러오기") {
                        Task { await model.loadNext() }
                    }
                    .disabled(model.isLoading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("탐색 · 검색")
            .searchable(text: $query, prompt: "제목, 장르, 키워드 검색")
            .onChange(of: query) { _, value in
                model.search(query: value, profile: profile)
            }
            .navigationDestination(for: CatalogTitle.self) { title in
                DetailView(title: title, profile: profile)
            }
        }
        .task(id: profile.id) { model.search(query: query, profile: profile) }
        .onDisappear { model.cancel() }
    }
}

public struct DetailView: View {
    public let title: CatalogTitle
    public let profile: ViewerProfile
    @State private var showPhase2Notice = false

    public init(title: CatalogTitle, profile: ViewerProfile) {
        self.title = title
        self.profile = profile
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PosterArtwork(title: title)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(title.name).font(.largeTitle.bold())
                Text("\(title.year) · \(title.typeLabel) · \(title.genre) · \(title.rating.rawValue)")
                    .foregroundStyle(.secondary)
                Text(title.synopsis)
                    .font(.body)
                Button {
                    showPhase2Notice = true
                } label: {
                    Label("재생 (Phase 2 예정)", systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(14)
                }
                .buttonStyle(.borderedProminent)
                .tint(StreamLabTheme.accent)
                Text("이 화면은 권리가 확인된 자체 Mock 콘텐츠의 상세 정보만 제공합니다. 영상 재생은 아직 구현되지 않았습니다.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(18)
        }
        .background(StreamLabTheme.background)
        .alert("재생 엔진 미구현", isPresented: $showPhase2Notice) {
            Button("확인", role: .cancel) { }
        } message: {
            Text("Phase 2에서 AVPlayer/HLS 재생과 상태 머신을 구현합니다.")
        }
    }
}
