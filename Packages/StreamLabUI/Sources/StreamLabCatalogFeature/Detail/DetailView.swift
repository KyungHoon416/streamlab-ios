import SwiftUI
import StreamLabDesignSystem
import StreamLabDomain

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
                if let title = model.store.detail {
                    CatalogArtwork(title: title)
                        .frame(height: 230)
                        .overlay(alignment: .bottomLeading) {
                            Text("STREAMLAB ORIGINAL")
                                .font(.caption.bold()).tracking(2)
                                .padding(16)
                        }
                }
                Text(model.store.detail?.name ?? (model.store.loading ? "불러오는 중…" : "콘텐츠를 열 수 없습니다"))
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("detail-title")
                if let title = model.store.detail {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) { metadata(title) }
                        VStack(alignment: .leading, spacing: 10) { metadata(title) }
                    }
                    Button { showsPlayback = true } label: { Label("데모 영상 재생", systemImage: "play.fill") }
                        .buttonStyle(StreamLabButtonStyle())
                        .accessibilityIdentifier("playback-open")
                    VStack(alignment: .leading, spacing: 12) {
                        Text("작품 소개").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                        Text(title.synopsis).font(.body).fixedSize(horizontal: false, vertical: true)
                        Text(title.genre).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    Text("오리지널 Mock 콘텐츠 · 재생 버튼은 테스트 영상을 엽니다.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button { model.retry() } label: { Label("상세 정보 다시 불러오기", systemImage: "arrow.clockwise") }
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

    @ViewBuilder private func metadata(_ title: CatalogTitle) -> some View {
        Text(title.rating.rawValue).font(.subheadline.bold())
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 6))
        Text("\(title.year) · \(title.typeLabel) · \(title.durationMinutes)분")
            .font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

}
