import UIKit
import StreamLabDomain
import StreamLabPresentation
import StreamLabDesignSystem

@MainActor public final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    public static func instantiate() -> SearchViewController {
        UIStoryboard(name: "Search", bundle: .module).instantiateViewController(withIdentifier: "Search") as! SearchViewController
    }

    @IBOutlet private weak var searchBar: UISearchBar!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var moreButton: UIButton!
    @IBOutlet private weak var loadingOverlay: UIView!
    @IBOutlet private weak var loadingCard: UIView!
    @IBOutlet private weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet private weak var loadingLabel: UILabel!
    public var store: CatalogStore!
    private var hasAppeared = false
    public var onSelect: ((String) -> Void)?
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "검색"
        searchBar.placeholder = "제목 또는 장르 검색"
        searchBar.accessibilityIdentifier = "catalog-search"
        searchBar.delegate = self
        tableView.accessibilityIdentifier = "search-results"
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 86
        tableView.keyboardDismissMode = .onDrag
        StreamLabTheme.configure(statusLabel, style: .body)
        StreamLabTheme.button(moreButton, title: "더 보기")
        moreButton.accessibilityIdentifier = "load-more"
        loadingCard.layer.cornerRadius = 18
        loadingCard.clipsToBounds = true
        loadingIndicator.color = StreamLabTheme.accent
        loadingIndicator.isAccessibilityElement = false
        StreamLabTheme.configure(loadingLabel, style: .body)
        loadingLabel.textAlignment = .center
        loadingOverlay.accessibilityIdentifier = "pagination-loading-overlay"
        loadingLabel.accessibilityIdentifier = "pagination-loading-label"
        moreButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.searchBar.resignFirstResponder()
            if self.store.errorMessage != nil { self.store.retry() } else { self.store.loadNext() }
        }, for: .touchUpInside)
        store.onChange = { [weak self] in self?.render() }
    }
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if store.resume() != nil { return }
        if !hasAppeared {
            hasAppeared = true
            store.search(searchBar.text ?? "", debounce: .zero)
        }
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store.suspend()
        setPaginationLoading(false)
    }
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { store.search(searchText) }
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    private func render() {
        statusLabel.text = store.errorMessage ?? (store.loading ? "검색 중…" : (store.items.isEmpty ? "검색 결과가 없습니다." : "\(store.items.count)개 표시 · \(store.profile.displayName)"))
        moreButton.isHidden = store.nextCursor == nil && store.errorMessage == nil
        moreButton.isEnabled = !store.loading
        let loadingMore = store.loading && store.nextCursor != nil
        var configuration = moreButton.configuration
        configuration?.showsActivityIndicator = false
        configuration?.imagePlacement = .leading
        configuration?.imagePadding = 8
        configuration?.title = loadingMore ? "불러오는 중…" : (store.errorMessage == nil ? "더 보기" : "다시 시도")
        moreButton.configuration = configuration
        moreButton.accessibilityLabel = loadingMore ? "다음 검색 결과 불러오는 중" : configuration?.title
        setPaginationLoading(loadingMore)
        tableView.reloadData()
    }
    private func setPaginationLoading(_ loading: Bool) {
        let wasVisible = !loadingOverlay.isHidden
        loadingOverlay.isHidden = !loading
        if loading {
            loadingIndicator.startAnimating()
            view.bringSubviewToFront(loadingOverlay)
            if !wasVisible {
                UIAccessibility.post(notification: .announcement, argument: loadingLabel.text)
            }
        } else {
            loadingIndicator.stopAnimating()
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { store.items.count }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Result") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "Result")
        let item = store.items[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.name
        config.secondaryText = "\(item.rating.rawValue) · \(item.genre) · \(item.year) · \(item.typeLabel)"
        config.textProperties.numberOfLines = 0
        config.secondaryTextProperties.numberOfLines = 0
        config.textProperties.adjustsFontForContentSizeCategory = true
        config.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        config.image = UIImage(systemName: "film.fill")
        config.imageProperties.tintColor = StreamLabTheme.accent
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = "result-\(item.id)"
        cell.accessibilityLabel = "\(item.name), \(item.rating.rawValue), \(item.genre)"
        cell.accessibilityTraits = .button
        return cell
    }
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(store.items[indexPath.row].id)
    }
}
