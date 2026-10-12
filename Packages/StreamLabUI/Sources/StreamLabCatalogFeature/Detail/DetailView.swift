import SwiftUI
import StreamLabDesignSystem

@MainActor public struct DetailView: View {
    @StateObject private var model: CatalogScreenModel
    @State private var showsPlaybackNotice = false
    @Environment(\.scenePhase) private var phase

    public init(id: String, session: CatalogSession) {
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
                    Button { showsPlaybackNotice = true } label: { Label("재생 · Phase 2 예정", systemImage: "play.fill") }
                        .buttonStyle(StreamLabButtonStyle())
                        .accessibilityIdentifier("phase2-playback")
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
        .alert("Phase 2 예정", isPresented: $showsPlaybackNotice) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("Phase 1은 탐색 기능을 제공합니다. 실제 영상 재생은 아직 구현되지 않았습니다.")
        }
        .onAppear { model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: phase) { _, value in model.setPhase(value) }
    }
}
