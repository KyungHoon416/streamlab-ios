import SwiftUI
import StreamLabDomain
import StreamLabPresentation
import StreamLabDesignSystem

@MainActor public struct HomeView: View {
    private let session: CatalogSession

    public init(session: CatalogSession) { self.session = session }

    public var body: some View {
        Group {
            if HomeRenderExperiment.current.splitHome {
                ExtractedHomeView(session: session)
            } else {
                InlineHomeView(session: session)
            }
        }
    }
}

@MainActor private struct ExtractedHomeView: View {
    @StateObject private var model: CatalogScreenModel
    @ObservedObject private var myList: MyListStore
    @State private var category: Category = .recommended
    @StateObject private var playbackOrientation = PlaybackOrientationSession()
    @State private var playbackTitle: CatalogTitle?
    @State private var cancelledPlaybackTitleID: String?
    @State private var showsCancelledPlaybackDetail = false
    @State private var playbackSource: PlaybackModel.Source = .bundled
    @State private var recentRefresh = UUID()
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

    init(session: CatalogSession) {
        self.session = session
        _myList = ObservedObject(wrappedValue: session.myList)
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .home))
    }

    var body: some View {
        let span = HomeStartupTrace.begin("HomeBodyValue")
        defer { withExtendedLifetime(span) {} }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let home = model.store.home {
                    categoryPicker
                    if category == .saved {
                        savedContents
                    } else {
                    if let featured = ([home.hero] + home.rails.flatMap(\.items)).first(where: category.includes) {
                        HomeHero(title: featured, myList: myList) {
                            playbackOrientation.begin()
                            playbackSource = .bundled
                            playbackTitle = featured
                        }
                    }
                    if category != .recommended {
                        Text("추천 콘텐츠 중 \(category.rawValue)")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 20)
                    }
                    ContinueWatchingSection(session: session, reloadID: recentRefresh,
                                            includes: category.includes) { item in
                        playbackOrientation.begin()
                        playbackSource = item.source
                        playbackTitle = item.title
                    }
                    ForEach(home.rails.filter { $0.items.contains(where: category.includes) }) { rail in
                        HomeRail(id: rail.id, title: rail.title,
                                 items: rail.items.filter(category.includes))
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
        #if DEBUG
        .accessibilityValue(ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--ui-test-progress-suite=") })
                            ? HomeRenderExperiment.current.description : "")
        #endif
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
        .onAppear { HomeStartupTrace.event("HomeAppeared"); myList.refresh(); model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in
            if value == .active { myList.refresh() }
            model.setPhase(value)
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
                            // Plain buttons must hit-test the padded chip, including its empty area.
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == value ? [.isSelected] : [])
                    .accessibilityIdentifier("home-category-\(value.rawValue)")
                }
            }
            .containerRelativeFrame(.horizontal, alignment: .leading)
        }
        .accessibilityIdentifier("home-category-scroll")
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // Bound interaction to layout, not the artwork's scaled image extent.
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(title.name), \(title.rating.rawValue) · \(title.genre)")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("my-list-\(title.id)")
                }
            }
        }.padding(.horizontal, 20)
    }

}

/// A concrete view boundary keeps the hero's layout type out of the entire home tree.
@MainActor private struct HomeHero: View {
    let title: CatalogTitle
    @ObservedObject var myList: MyListStore
    let onPlay: () -> Void
    @Environment(\.streamLabContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var textSize

    var body: some View {
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
            .background { HomeStartupLayoutMarker() }
            Group {
                if textSize.isAccessibilitySize {
                    VStack(spacing: 12) { heroActions }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { heroActions }
                        VStack(spacing: 12) { heroActions }
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
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(contrast == .increased ? 1 : 0.12)))
        .padding(.horizontal, 20)
    }

    @ViewBuilder private var heroActions: some View {
        Button(action: onPlay) {
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


@MainActor private struct HomeRail: View {
    let id: String
    let title: String
    let items: [CatalogTitle]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(value: item.id) { CatalogPoster(title: item) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.name), \(item.rating.rawValue)")
                            .accessibilityIdentifier("rail-\(id)-\(item.id)")
                    }
                }.padding(.horizontal)
            }
        }
    }
}
