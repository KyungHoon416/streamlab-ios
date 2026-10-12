import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor public struct HomeView: View {
    @StateObject private var model: CatalogScreenModel
    @Environment(\.scenePhase) private var phase

    public init(session: CatalogSession) {
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .home))
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if let home = model.store.home {
                    hero(home.hero)
                    if !home.continueWatching.isEmpty {
                        Text("계속 시청").font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
                        ScrollView(.horizontal) {
                            LazyHStack(alignment: .top, spacing: 16) {
                                ForEach(home.continueWatching) { progress in
                                    NavigationLink(value: progress.id) {
                                        VStack(alignment: .leading) {
                                            CatalogPoster(title: progress.title)
                                            ProgressView(value: progress.fraction).tint(StreamLabTheme.accent)
                                        }.frame(width: 160)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(progress.title.name), \(progress.title.rating.rawValue), \(Int(progress.fraction * 100))퍼센트 시청")
                                    .accessibilityIdentifier("continue-\(progress.id)")
                                }
                            }.padding(.horizontal)
                        }
                    }
                    ForEach(home.rails) { rail in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(rail.title).font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
                            ScrollView(.horizontal) {
                                LazyHStack(alignment: .top, spacing: 16) {
                                    ForEach(rail.items) { title in
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
        .onAppear { model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in model.setPhase(value) }
    }

    private func hero(_ title: CatalogTitle) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            CatalogArtwork(title: title).frame(height: 220)
            Text("오늘의 추천").font(.caption.bold()).foregroundStyle(StreamLabTheme.accent)
            Text(title.name).font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Text("\(title.year) · \(title.rating.rawValue) · \(title.genre)").foregroundStyle(.secondary)
            Text(title.synopsis).font(.body).fixedSize(horizontal: false, vertical: true)
            NavigationLink(value: title.id) { Label("상세 정보", systemImage: "info.circle") }
                .buttonStyle(StreamLabButtonStyle())
                .accessibilityIdentifier("hero-detail")
        }
        .padding()
    }
}
