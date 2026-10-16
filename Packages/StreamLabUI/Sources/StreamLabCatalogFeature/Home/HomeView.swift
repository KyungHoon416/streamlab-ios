import SwiftUI
import StreamLabDomain
import StreamLabPresentation
import StreamLabDesignSystem

@MainActor public struct HomeView: View {
    @StateObject private var model: CatalogScreenModel
    @ObservedObject private var myList: MyListStore
    @State private var category: Category = .recommended
    @StateObject private var playbackOrientation = PlaybackOrientationSession()
    @State private var playbackTitle: CatalogTitle?
    @State private var cancelledPlaybackTitleID: String?
    @State private var showsCancelledPlaybackDetail = false
    @State private var playbackSource: PlaybackModel.Source = .bundled
    @State private var recent: [RecentItem] = []
    @State private var recentRefresh = UUID()
    @State private var recentError = false
    private struct RecentItem: Identifiable {
        let title: CatalogTitle
        let entry: PlaybackProgressStore.Entry
        let source: PlaybackModel.Source
        var id: String { title.id }
    }
    private let session: CatalogSession
    private enum Category: String, CaseIterable {
        case recommended = "추천", movies = "영화", series = "시리즈", saved = "나의 리스트"
        func includes(_ title: CatalogTitle) -> Bool {
            switch self {
            case .recommended, .saved: true
            case .movies: title.kind == .movie
            case .series: title.kind == .series
            }
        }
    }
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.scenePhase) private var phase

    public init(session: CatalogSession) {
        self.session = session
        _myList = ObservedObject(wrappedValue: session.myList)
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .home))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let home = model.store.home {
                    categoryPicker
                    if category == .saved {
                        savedContents
                    } else {
                    if let featured = ([home.hero] + home.rails.flatMap(\.items)).first(where: category.includes) {
                        hero(featured)
                    }
                    if category != .recommended {
                        Text("추천 콘텐츠 중 \(category.rawValue)")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 20)
                    }
                    continueWatching
                    ForEach(home.rails.filter { $0.items.contains(where: category.includes) }) { rail in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(rail.title).font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
                            ScrollView(.horizontal) {
                                LazyHStack(alignment: .top, spacing: 16) {
                                    ForEach(rail.items.filter(category.includes)) { title in
                                        NavigationLink(value: title.id) { CatalogPoster(title: title) }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel("\(title.name), \(title.rating.rawValue)")
                                            .accessibilityIdentifier("rail-\(rail.id)-\(title.id)")
                                    }
                                }.padding(.horizontal)
                            }
                        }
                    }
                    }
                } else if model.store.loading {
                    ProgressView("홈을 불러오는 중…").frame(maxWidth: .infinity).padding(32)
                }
                if let error = model.store.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                        Button("다시 시도") { model.retry() }.buttonStyle(StreamLabButtonStyle())
                    }.padding()
                }
            }
            .padding(.bottom, 24)
        }
        // Each category owns its scroll/layout identity. Keep the model and
        // presentation state outside this boundary so switching does not reload data.
        .id(category)
        .accessibilityIdentifier("home-catalog")
        .background(PlaybackPresenterScene(session: playbackOrientation).frame(width: 0, height: 0))
        .background(StreamLabTheme.background)
        .navigationTitle("STREAMLAB")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playbackTitle, onDismiss: {
            playbackOrientation.finish()
            recentRefresh = UUID()
            if cancelledPlaybackTitleID != nil { showsCancelledPlaybackDetail = true }
        }) { title in
            PlaybackView(titleID: title.id, title: title.name, session: session, orientationSession: playbackOrientation, initialSource: playbackSource,
                         onCancelFailure: { cancelledPlaybackTitleID = title.id })
                .id("\(session.id.uuidString):\(title.id)")
        }
        .navigationDestination(isPresented: $showsCancelledPlaybackDetail) {
            if let id = cancelledPlaybackTitleID { DetailView(id: id, session: session) }
        }
        .onChange(of: showsCancelledPlaybackDetail) { _, showing in
            if !showing { cancelledPlaybackTitleID = nil }
        }
        .task(id: recentRefresh) { await refreshRecent() }
        .onAppear { recentRefresh = UUID(); myList.refresh(); model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in
            if value == .active { myList.refresh(); recentRefresh = UUID() }
            model.setPhase(value)
        }
    }

    private func refreshRecent() async {
        let ticket = recentRefresh
        let entries = session.progress.recent()
        var result: [RecentItem] = []
        var failed = false
        for entry in entries {
            guard !Task.isCancelled, session.isActive, ticket == recentRefresh else { return }
            guard let source = PlaybackModel.Source.allCases.first(where: { $0.progressID == entry.sourceID }) else { continue }
            do {
                if let title = try await session.repository.detail(id: entry.titleID, profile: session.profile),
                   title.canView(in: session.profile) {
                    result.append(RecentItem(title: title, entry: entry, source: source))
                }
            } catch {
                if Task.isCancelled { return }
                failed = true
            }
        }
        guard !Task.isCancelled, session.isActive, ticket == recentRefresh else { return }
        recent = result
        recentError = failed
    }

    private var continueWatching: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("계속 시청").font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
            if recentError {
                Button("시청 기록 다시 불러오기") { recentRefresh = UUID() }
                    .padding(.horizontal).accessibilityIdentifier("continue-retry")
            }
            if recent.isEmpty && !recentError {
                Text("시청 중인 작품이 없습니다. 영상을 재생하면 여기에 표시됩니다.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal)
                    .accessibilityIdentifier("continue-empty")
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(recent.filter { category.includes($0.title) }) { item in
                        Button {
                            playbackOrientation.begin()
                            playbackSource = item.source
                            playbackTitle = item.title
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CatalogArtwork(title: item.title).frame(height: 112)
                                ProgressView(value: item.entry.position / item.entry.duration)
                                    .tint(StreamLabTheme.accent)
                                Text(item.title.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                Text("\(Int(item.entry.position))초 / \(Int(item.entry.duration))초 · \(item.source.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }.frame(width: 210, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title.name), \(item.title.rating.rawValue), \(Int(item.entry.position / item.entry.duration * 100))퍼센트 시청, 이어보기")
                        .accessibilityIdentifier("continue-\(item.id)")
                    }
                }.padding(.horizontal)
            }
        }
    }

    private var categoryPicker: some View {
        // AnyLayout preserves button identity while changing the layout axis.
        let layout = textSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return ScrollView(.horizontal) {
            layout {
                ForEach(Category.allCases, id: \.self) { value in
                    Button { category = value } label: {
                        Text(value.rawValue)
                            .font(.headline)
                            .lineLimit(nil)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: textSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 44, alignment: .leading)
                            .background(category == value ? StreamLabTheme.accent : StreamLabTheme.surface,
                                        in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == value ? [.isSelected] : [])
                    .accessibilityIdentifier("home-category-\(value.rawValue)")
                }
            }
            .containerRelativeFrame(.horizontal, alignment: .leading)
        }
        .scrollDisabled(textSize.isAccessibilitySize)
        .scrollIndicators(.hidden)
        .padding(.horizontal, 20)
    }

    private var savedContents: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("나의 리스트").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            if myList.items.isEmpty {
                Text("아직 추가한 작품이 없습니다. 작품의 ‘나의 리스트 추가’를 눌러 보세요.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("my-list-empty")
            }
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(myList.items) { title in
                    NavigationLink(value: title.id) {
                        VStack(alignment: .leading, spacing: 8) {
                            CatalogArtwork(title: title).frame(height: 150)
                            Text(title.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                            Text("\(title.rating.rawValue) · \(title.genre)").font(.subheadline)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("my-list-\(title.id)")
                }
            }
        }.padding(.horizontal, 20)
    }

    private func hero(_ title: CatalogTitle) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink(value: title.id) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("STREAMLAB ORIGINAL · 오늘의 추천")
                        .font(.caption.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text(title.name).font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(String(title.year)) · \(title.rating.rawValue) · \(title.genre)")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .padding(24).padding(.top, textSize.isAccessibilitySize ? 24 : 115)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title.name), 상세 정보")
            .accessibilityHint("작품 상세 화면을 엽니다")
            .accessibilityIdentifier("hero-detail")
            Group {
                if textSize.isAccessibilitySize {
                    VStack(spacing: 12) { heroActions(title) }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { heroActions(title) }
                        VStack(spacing: 12) { heroActions(title) }
                    }
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
        .background {
            CatalogArtwork(title: title)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
        .padding(.horizontal, 20)
    }

    @ViewBuilder private func heroActions(_ title: CatalogTitle) -> some View {
        Button {
            playbackOrientation.begin()
            playbackSource = .bundled
            playbackTitle = title
        } label: {
            Label {
                Text("데모 재생").fixedSize(horizontal: false, vertical: true)
            } icon: { Image(systemName: "play.fill") }
        }
            .buttonStyle(StreamLabButtonStyle())
            .accessibilityIdentifier("hero-playback")
        MyListButton(title: title, store: myList)
            .accessibilityIdentifier("hero-my-list")
    }
}

