import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor struct ContinueWatchingSection: View {
    let session: CatalogSession
    let reloadID: UUID
    let includes: (CatalogTitle) -> Bool
    let onPlay: (HomeRecentModel.Item) -> Void
    @StateObject private var model: HomeRecentModel
    @State private var retryID = UUID()
    @Environment(\.scenePhase) private var phase
    private struct LoadKey: Equatable { let reload: UUID; let retry: UUID; let active: Bool }

    init(session: CatalogSession, reloadID: UUID, includes: @escaping (CatalogTitle) -> Bool,
         onPlay: @escaping (HomeRecentModel.Item) -> Void) {
        self.session = session
        self.reloadID = reloadID
        self.includes = includes
        self.onPlay = onPlay
        _model = StateObject(wrappedValue: HomeRecentModel(session: session))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("계속 시청").font(.title2.bold()).accessibilityAddTraits(.isHeader).padding(.horizontal)
            if model.snapshot.failed {
                Button("시청 기록 다시 불러오기") { retryID = UUID() }
                    .padding(.horizontal).accessibilityIdentifier("continue-retry")
            }
            if model.snapshot.items.isEmpty && !model.snapshot.failed {
                Text("시청 중인 작품이 없습니다. 영상을 재생하면 여기에 표시됩니다.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal)
                    .accessibilityIdentifier("continue-empty")
            }
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(model.snapshot.items.filter { includes($0.title) }) { item in
                        Button {
                            guard session.isActive else { return }
                            // The progress ID is shared by streaming and downloaded HLS.
                            // Resolve only on tap: a cached list must not keep stale file state.
                            let downloads = OfflineDownloadStore.shared
                            var source = item.source
                            if (source == .hls || source == .catalogHLS || source == .catalogMP4),
                               downloads.hasPlayableDownload(session: session, titleID: item.id) {
                                if source == .hls {
                                    source = .downloadedHLS
                                } else if let saved = downloads.record(session: session, titleID: item.id)?.catalogTitle?.streamURL,
                                          CatalogVideoIdentity.progressID(for: saved) == item.entry.sourceID {
                                    source = source == .catalogMP4 ? .downloadedCatalogMP4 : .downloadedCatalogHLS
                                }
                            }
                            onPlay(HomeRecentModel.Item(title: item.title, entry: item.entry, source: source))
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                CatalogArtwork(title: item.title).frame(height: 112)
                                ProgressView(value: item.entry.position / item.entry.duration)
                                    .tint(StreamLabTheme.accent)
                                Text(item.title.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                                Text("\(Int(item.entry.position))초 / \(Int(item.entry.duration))초 · \(item.source.rawValue)")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 210, alignment: .leading)
                            .contentShape(Rectangle())
                            .accessibilityElement(children: .ignore)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title.name), \(item.title.rating.rawValue), \(Int(item.entry.position / item.entry.duration * 100))퍼센트 시청, 이어보기")
                        .accessibilityIdentifier("continue-\(item.id)")
                    }
                }.padding(.horizontal)
            }
        }
        .task(id: LoadKey(reload: reloadID, retry: retryID, active: phase == .active)) {
            guard phase == .active else { return }
            await model.refresh()
        }
    }

}
