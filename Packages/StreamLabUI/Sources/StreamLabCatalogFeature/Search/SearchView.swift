import SwiftUI
import StreamLabDomain
import StreamLabDesignSystem

@MainActor public struct SearchView: View {
    @StateObject private var model: CatalogScreenModel
    @State private var query = ""
    @Environment(\.scenePhase) private var phase

    public init(session: CatalogSession) {
        _model = StateObject(wrappedValue: CatalogScreenModel(session: session, screen: .search))
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("제목 또는 장르 검색", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .accessibilityIdentifier("catalog-search-field")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").frame(minWidth: 44, minHeight: 44) }
                        .accessibilityLabel("검색어 지우기")
                        .accessibilityIdentifier("clear-search")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 52)
            .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            Text("결과 \(model.store.items.count)개")
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .accessibilityIdentifier("search-result-count")
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(model.store.items) { title in
                        NavigationLink(value: title.id) {
                            HStack(alignment: .top, spacing: 16) {
                                CatalogArtwork(title: title).frame(width: 72, height: 100)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(title.name).font(.headline)
                                    Text("\(title.year) · \(title.rating.rawValue) · \(title.genre)").font(.subheadline).foregroundStyle(.secondary)
                                }.fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                            .padding(12)
                            .background(StreamLabTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(title.name), \(title.rating.rawValue), \(title.genre)")
                        .accessibilityIdentifier("search-title-\(title.id)")
                    }
                    if model.store.items.isEmpty && !model.store.loading && model.store.errorMessage == nil {
                        ContentUnavailableView("검색 결과가 없습니다", systemImage: "magnifyingglass", description: Text("다른 제목이나 장르를 입력해 주세요."))
                    }
                }.padding(.horizontal)
            }
            .accessibilityIdentifier("search-results")
            .scrollDismissesKeyboard(.interactively)
            if let error = model.store.errorMessage {
                Text(error).font(.callout).padding(.horizontal)
                Button("다시 시도") { model.retry() }.buttonStyle(StreamLabButtonStyle()).padding(.horizontal)
            }
            if model.store.nextCursor != nil {
                Button("더 보기") { model.loadNext() }
                    .buttonStyle(StreamLabButtonStyle())
                    .disabled(model.store.loading)
                    .opacity(model.store.loading ? 0.55 : 1)
                    .accessibilityIdentifier("load-more")
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        // Overlay is content-scoped; the profile toolbar and tab navigation stay available.
        .overlay {
            if model.store.loading { LoadingCard().allowsHitTesting(false) }
        }
        .background(StreamLabTheme.background)
        .navigationTitle("검색")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.appear(phase: phase) }
        .onDisappear { model.disappear() }
        .onChange(of: query) { _, value in model.search(value) }
        .onChange(of: phase) { _, value in model.setPhase(value) }
        .onChange(of: model.store.loading) { wasLoading, loading in
            if !wasLoading && loading && !model.store.items.isEmpty {
                AccessibilityNotification.Announcement("콘텐츠를 가져오고 있어요").post()
            } else if wasLoading && !loading {
                AccessibilityNotification.Announcement("검색 결과 \(model.store.items.count)개").post()
            }
        }
    }
}
