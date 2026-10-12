import SwiftUI
import StreamLabDesignSystem

@MainActor public struct DetailView: View {
    @StateObject private var model: CatalogScreenModel
    @State private var showsPlayback = false
    private let session: CatalogSession
    @Environment(\.scenePhase) private var phase

    public init(id: String, session: CatalogSession) {
        self.session = session
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .detail(id)))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.store.detail?.name ?? (model.store.loading ? "불러오는 중…" : "콘텐츠를 열 수 없습니다"))
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("detail-title")
                Button("다시 시도") { model.retry() }
                    .buttonStyle(StreamLabButtonStyle())
                    .disabled(model.store.loading)
                    .opacity(model.store.loading ? 0.55 : 1)
                    .accessibilityIdentifier("detail-retry")
                if let title = model.store.detail {
                    CatalogArtwork(title: title).frame(height: 200)
                    Text("\(title.year) · \(title.rating.rawValue) · \(title.typeLabel) · \(title.durationMinutes)분\n\(title.genre)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text(title.synopsis).font(.body)
                    Text("오리지널 Mock 콘텐츠 · 실제 상용 영상이 아닙니다.").font(.callout).foregroundStyle(.secondary)
                    Button { showsPlayback = true } label: { Label("데모 영상 재생", systemImage: "play.fill") }
                        .buttonStyle(StreamLabButtonStyle())
                        .accessibilityIdentifier("playback-open")
                }
                if model.store.loading { ProgressView("콘텐츠를 불러오는 중…") }
                if let error = model.store.errorMessage { Text(error).foregroundStyle(.secondary) }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(StreamLabTheme.background)
        .navigationTitle("콘텐츠 상세")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showsPlayback) {
            if let title = model.store.detail {
                PlaybackView(titleID: title.id, title: title.name, session: session)
            }
        }
        .onAppear { model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in model.setPhase(value) }
    }
}
