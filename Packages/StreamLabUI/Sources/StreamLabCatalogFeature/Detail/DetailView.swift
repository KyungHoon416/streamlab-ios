import SwiftUI
import StreamLabDesignSystem
import StreamLabDomain

@MainActor public struct DetailView: View {
    @StateObject private var model: CatalogScreenModel
    @ObservedObject private var myList: MyListStore
    @StateObject private var playbackOrientation = PlaybackOrientationSession()
    @State private var showsPlayback = false
    @State private var playbackSource: PlaybackModel.Source = .bundled
    @State private var episodePositions: [String: Double] = [:]
    private let session: CatalogSession
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(id: String, session: CatalogSession) {
        self.session = session
        _myList = ObservedObject(wrappedValue: session.myList)
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .detail(id)))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let title = model.store.detail {
                    if dynamicTypeSize.isAccessibilitySize {
                        previewArtwork(title)
                        originalLabel
                    } else {
                        previewArtwork(title)
                            .overlay(alignment: .bottomLeading) {
                                originalLabel.padding(16)
                            }
                    }
                }
                Text(model.store.detail?.name ?? (model.store.loading ? "불러오는 중…" : "콘텐츠를 열 수 없습니다"))
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("detail-title")
                if let title = model.store.detail {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            ratingBadge(title)
                            Text(String(title.year))
                                .accessibilityIdentifier("detail-year")
                            Text(title.typeLabel)
                                .accessibilityIdentifier("detail-type")
                            Text("\(title.durationMinutes)분")
                                .accessibilityIdentifier("detail-duration")
                        }
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) { metadata(title) }
                            VStack(alignment: .leading, spacing: 10) { metadata(title) }
                        }
                    }
                    Button {
                        openPlayback(.bundled)
                    } label: {
                        Label {
                            Text("데모 영상 재생")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: { Image(systemName: "play.fill") }
                    }
                        .buttonStyle(StreamLabButtonStyle())
                        .accessibilityIdentifier("playback-open")
                    MyListButton(title: title, store: myList)
                        .accessibilityIdentifier("detail-my-list")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("작품 소개").font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(title.synopsis).font(.body).fixedSize(horizontal: false, vertical: true)
                        Text(title.genre).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    DetailEpisodeSection(title: title, positions: episodePositions, onSelect: openPlayback)
                    Text("오리지널 Mock 콘텐츠 · 재생 버튼은 테스트 영상을 엽니다.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button { model.retry() } label: {
                    Label {
                        Text("상세 정보 다시 불러오기")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: { Image(systemName: "arrow.clockwise") }
                }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .disabled(model.store.loading)
                    .opacity(model.store.loading ? 0.55 : 1)
                    .accessibilityIdentifier("detail-retry")
                if model.store.loading { ProgressView("콘텐츠를 불러오는 중…") }
                if let error = model.store.errorMessage { Text(error).foregroundStyle(.secondary) }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("detail-scroll")
        .background(PlaybackPresenterScene(session: playbackOrientation).frame(width: 0, height: 0))
        .background(StreamLabTheme.background)
        .navigationTitle("콘텐츠 상세")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showsPlayback, onDismiss: { playbackOrientation.finish(); refreshEpisodeProgress() }) {
            if let title = model.store.detail {
                PlaybackView(titleID: title.id, title: title.name, session: session, orientationSession: playbackOrientation, initialSource: playbackSource)
                    .id("\(session.id.uuidString):\(title.id)")
            }
        }
        .onAppear { model.appear(phase: phase); refreshEpisodeProgress() }
        .onChange(of: model.store.detail?.id) { _, _ in refreshEpisodeProgress() }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in
            model.setPhase(value)
            if value == .active { refreshEpisodeProgress() }
        }
    }

    private func openPlayback(_ source: PlaybackModel.Source) {
        guard session.isActive, !showsPlayback else { return }
        playbackSource = source
        playbackOrientation.begin()
        showsPlayback = true
    }

    private func refreshEpisodeProgress() {
        guard session.isActive, let title = model.store.detail else {
            episodePositions = [:]
            return
        }
        episodePositions = Dictionary(uniqueKeysWithValues: DetailEpisodeSection.sources.compactMap { source -> (String, Double)? in
            guard let position = session.progress.position(titleID: title.id, sourceID: source.progressID, duration: 30) else { return nil }
            return (source.progressID, position)
        })
    }

    private func previewArtwork(_ title: CatalogTitle) -> some View {
        Button { openPlayback(.bundled) } label: {
            CatalogArtwork(title: title)
                .frame(height: 230)
                .overlay {
                    Label("데모 미리보기", systemImage: "play.circle.fill")
                        .font(.headline)
                        .padding(12)
                        .background(.black.opacity(0.8), in: Capsule())
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("데모 미리보기 재생")
        .accessibilityIdentifier("detail-preview")
    }

    private var originalLabel: some View {
        Text("STREAMLAB ORIGINAL")
            .font(.caption.bold()).tracking(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("detail-original")
    }

    private func ratingBadge(_ title: CatalogTitle) -> some View {
        Text(title.rating.rawValue).font(.subheadline.bold())
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("detail-rating")
    }

    @ViewBuilder private func metadata(_ title: CatalogTitle) -> some View {
        ratingBadge(title)
        Text("\(String(title.year)) · \(title.typeLabel) · \(title.durationMinutes)분")
            .font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

}

