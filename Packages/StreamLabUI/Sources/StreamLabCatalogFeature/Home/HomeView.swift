import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor public struct HomeView: View {
    @StateObject private var model: CatalogScreenModel
    @State private var category: Category = .recommended
    @State private var playbackTitle: CatalogTitle?
    private let session: CatalogSession
    private enum Category: String, CaseIterable {
        case recommended = "추천", movies = "영화", series = "시리즈"
        func includes(_ title: CatalogTitle) -> Bool {
            switch self {
            case .recommended: true
            case .movies: title.kind == .movie
            case .series: title.kind == .series
            }
        }
    }
    @Environment(\.scenePhase) private var phase

    public init(session: CatalogSession) {
        self.session = session
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .home))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let home = model.store.home {
                    categoryPicker
                    if let featured = ([home.hero] + home.rails.flatMap(\.items)).first(where: category.includes) {
                        hero(featured)
                    }
                    if category != .recommended {
                        Text("추천 콘텐츠 중 \(category.rawValue)")
                            .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, 20)
                    }
                    if home.continueWatching.contains(where: { category.includes($0.title) }) {
                        Text("계속 시청").font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(home.continueWatching.filter { category.includes($0.title) }) { progress in
                                    NavigationLink(value: progress.id) {
                                        VStack(alignment: .leading) {
                                            CatalogArtwork(title: progress.title).frame(height: 112)
                                            ProgressView(value: progress.fraction).tint(StreamLabTheme.accent)
                                            Text(progress.title.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                            Text("\(max(0, (progress.durationSeconds - progress.positionSeconds) / 60))분 남음")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }.frame(width: 210, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(progress.title.name), \(progress.title.rating.rawValue), \(Int(progress.fraction * 100))퍼센트 시청")
                                    .accessibilityIdentifier("continue-\(progress.id)")
                                }
                            }.padding(.horizontal)
                        }
                    }
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
        .accessibilityIdentifier("home-catalog")
        .background(StreamLabTheme.background)
        .navigationTitle("STREAMLAB")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $playbackTitle) { title in
            PlaybackView(titleID: title.id, title: title.name, session: session)
        }
        .onAppear { model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in model.setPhase(value) }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Category.allCases, id: \.self) { value in
                    Button { category = value } label: {
                        Text(value.rawValue).font(.headline)
                            .padding(.horizontal, 22).frame(minHeight: 44)
                            .background(category == value ? StreamLabTheme.accent : StreamLabTheme.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == value ? [.isSelected] : [])
                    .accessibilityIdentifier("home-category-\(value.rawValue)")
                }
            }.padding(.horizontal, 20)
        }.scrollIndicators(.hidden)
    }

    private func hero(_ title: CatalogTitle) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("STREAMLAB ORIGINAL · 오늘의 추천")
                .font(.caption.bold()).foregroundStyle(.white)
            Text(title.name).font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(title.year) · \(title.rating.rawValue) · \(title.genre)")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { heroActions(title) }
                VStack(spacing: 12) { heroActions(title) }
            }
        }
        .padding(24)
        .padding(.top, 115)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            CatalogArtwork(title: title)
                .overlay(LinearGradient(colors: [.clear, .black.opacity(0.95)], startPoint: .top, endPoint: .bottom))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12)))
        .padding(.horizontal, 20)
    }

    @ViewBuilder private func heroActions(_ title: CatalogTitle) -> some View {
        Button { playbackTitle = title } label: { Label("데모 재생", systemImage: "play.fill") }
            .buttonStyle(StreamLabButtonStyle())
            .accessibilityIdentifier("hero-playback")
        NavigationLink(value: title.id) { Label("상세 정보", systemImage: "info.circle") }
            .buttonStyle(StreamLabButtonStyle())
            .accessibilityIdentifier("hero-detail")
    }
}
