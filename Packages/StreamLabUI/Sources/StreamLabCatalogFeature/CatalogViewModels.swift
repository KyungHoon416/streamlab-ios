import Foundation
import Observation
import StreamLabDomain

@MainActor @Observable
public final class HomeViewModel {
    public private(set) var snapshot: HomeSnapshot?
    public private(set) var loading = false
    public private(set) var errorMessage: String?
    private let repository: any CatalogRepository
    private var generation = 0

    public init(repository: any CatalogRepository) { self.repository = repository }

    public func load(profile: ViewerProfile) async {
        generation += 1
        let mine = generation
        snapshot = nil
        errorMessage = nil
        loading = true
        defer { if mine == generation { loading = false } }
        do {
            let result = try await repository.home(profile: profile)
            guard mine == generation, !Task.isCancelled else { return }
            snapshot = result
        } catch is CancellationError {
        } catch {
            guard mine == generation else { return }
            errorMessage = "콘텐츠를 불러오지 못했습니다. 다시 시도해 주세요."
        }
    }

    public func clear() {
        generation += 1
        snapshot = nil
        loading = false
    }
}

@MainActor @Observable
public final class SearchViewModel {
    public private(set) var items: [CatalogTitle] = []
    public private(set) var nextCursor: String?
    public private(set) var isLoading = false
    public private(set) var errorMessage: String?
    private let repository: any CatalogRepository
    private var task: Task<Void, Never>?
    private var generation = 0
    private var currentQuery = ""
    private var currentProfile: ViewerProfile?

    public init(repository: any CatalogRepository) { self.repository = repository }

    public func search(query: String, profile: ViewerProfile) {
        task?.cancel()
        generation += 1
        let mine = generation
        currentQuery = query
        currentProfile = profile
        items = []
        nextCursor = nil
        errorMessage = nil
        isLoading = true
        task = Task { [repository] in
            do {
                try await Task.sleep(for: .milliseconds(240))
                let page = try await repository.search(query, profile: profile, after: nil, limit: 24)
                guard !Task.isCancelled, mine == generation else { return }
                items = page.items
                nextCursor = page.nextCursor
                isLoading = false
            } catch is CancellationError {
            } catch {
                guard mine == generation else { return }
                errorMessage = "검색에 실패했습니다. 다시 시도해 주세요."
                isLoading = false
            }
        }
    }

    public func loadNext() async {
        guard !isLoading, let cursor = nextCursor, let profile = currentProfile else { return }
        let mine = generation
        isLoading = true
        defer { if mine == generation { isLoading = false } }
        do {
            let page = try await repository.search(currentQuery, profile: profile, after: cursor, limit: 24)
            guard mine == generation, !Task.isCancelled else { return }
            let known = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !known.contains($0.id) })
            nextCursor = page.nextCursor
        } catch is CancellationError {
        } catch {
            guard mine == generation else { return }
            errorMessage = "추가 검색 결과를 불러오지 못했습니다."
        }
    }

    public func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        isLoading = false
        items = []
        nextCursor = nil
    }
}
