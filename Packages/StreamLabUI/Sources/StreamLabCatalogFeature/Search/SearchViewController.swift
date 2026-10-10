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
    public var store: CatalogStore!
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
        moreButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if self.store.errorMessage != nil { self.store.retry() } else { self.store.loadNext() }
        }, for: .touchUpInside)
        store.onChange = { [weak self] in self?.render() }
    }
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.search(searchBar.text ?? "", debounce: .zero)
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store.invalidate()
    }
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) { store.search(searchText) }
    public func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder() }
    private func render() {
        statusLabel.text = store.errorMessage ?? (store.loading ? "검색 중…" : (store.items.isEmpty ? "검색 결과가 없습니다." : "\(store.items.count)개 표시 · \(store.profile.displayName)"))
        moreButton.isHidden = store.nextCursor == nil && store.errorMessage == nil
        moreButton.isEnabled = !store.loading
        moreButton.configuration?.title = store.errorMessage == nil ? "더 보기" : "다시 시도"
        tableView.reloadData()
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
