import Foundation
import StreamLabDomain

/// One screen owns one store. UIKit and tests exercise this same state boundary.
@MainActor
public final class CatalogStore {
    public private(set) var profile: ViewerProfile
    public private(set) var home: HomeSnapshot?
    public private(set) var items: [CatalogTitle] = []
    public private(set) var detail: CatalogTitle?
    public private(set) var query = ""
    public private(set) var nextCursor: String?
    public private(set) var loading = false
    public private(set) var errorMessage: String?
    public var onChange: (@MainActor () -> Void)?
    private let repository: any CatalogRepository
    private var task: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var consumedCursors: Set<String> = []
    private var lastRequest: Request?

    private enum Request: Sendable {
        case home, detail(String), search(String, String?)
    }
    private enum Response: Sendable {
        case home(HomeSnapshot), detail(CatalogTitle?), page(CatalogPage)
    }

    public init(profile: ViewerProfile, repository: any CatalogRepository) {
        self.profile = profile
        self.repository = repository
    }
    deinit { task?.cancel() }

    /// Synchronously clears all data before any request for a new profile can begin.
    public func select(_ profile: ViewerProfile) {
        invalidate()
        self.profile = profile
        onChange?()
    }
    public func invalidate() {
        generation &+= 1
        task?.cancel()
        task = nil
        home = nil
        items = []
        detail = nil
        nextCursor = nil
        consumedCursors = []
        errorMessage = nil
        loading = false
        query = ""
        lastRequest = nil
        onChange?()
    }
    @discardableResult public func loadHome() -> Task<Void, Never> {
        home = nil
        return begin(.home)
    }
    @discardableResult public func loadDetail(id: String) -> Task<Void, Never> {
        detail = nil
        return begin(.detail(id))
    }
    @discardableResult public func search(_ query: String, debounce: Duration = .milliseconds(240)) -> Task<Void, Never> {
        self.query = query
        items = []
        nextCursor = nil
        consumedCursors = []
        return begin(.search(query, nil), debounce: debounce)
    }
    @discardableResult public func loadNext() -> Task<Void, Never>? {
        guard !loading, let nextCursor else { return nil }
        return begin(.search(query, nextCursor))
    }
    @discardableResult public func retry() -> Task<Void, Never>? {
        guard !loading, let lastRequest else { return nil }
        return begin(lastRequest)
    }

    private func begin(_ request: Request, debounce: Duration = .zero) -> Task<Void, Never> {
        task?.cancel()
        generation &+= 1
        let ticket = generation
        let requestedProfile = profile
        let repository = repository
        lastRequest = request
        loading = true
        errorMessage = nil
        onChange?()
        // No strong self across await: a repository ignoring cancellation cannot retain a screen.
        let work = Task { [weak self] in
            do {
                if debounce > .zero { try await Task.sleep(for: debounce) }
                try Task.checkCancellation()
                let response: Response
                switch request {
                case .home:
                    response = .home(try await repository.home(profile: requestedProfile))
                case .detail(let id):
                    response = .detail(try await repository.detail(id: id, profile: requestedProfile))
                case .search(let query, let cursor):
                    response = .page(try await repository.search(query, profile: requestedProfile, after: cursor, limit: 24))
                }
                guard let self, self.generation == ticket,
                      self.profile == requestedProfile, !Task.isCancelled else { return }
                switch response {
                case .home(let value): self.home = value
                case .detail(let value):
                    self.detail = value
                    if value == nil { self.errorMessage = "콘텐츠가 없거나 이 프로필에서 이용할 수 없습니다." }
                case .page(let page):
                    var known = Set(self.items.map(\.id))
                    self.items.append(contentsOf: page.items.filter { known.insert($0.id).inserted })
                    if case .search(_, let cursor) = request, let cursor { self.consumedCursors.insert(cursor) }
                    if let cursor = page.nextCursor, self.consumedCursors.contains(cursor) {
                        self.nextCursor = nil
                        self.errorMessage = "반복된 페이지 응답을 중단했습니다. 검색을 다시 실행해 주세요."
                    } else { self.nextCursor = page.nextCursor }
                }
                self.loading = false
                self.onChange?()
            } catch {
                guard let self, self.generation == ticket,
                      self.profile == requestedProfile else { return }
                self.loading = false
                if !(error is CancellationError) && !Task.isCancelled {
                    self.errorMessage = "불러오지 못했습니다. 다시 시도해 주세요."
                }
                self.onChange?()
            }
        }
        task = work
        return work
    }
}
