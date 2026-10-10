import UIKit
import StreamLabDomain
import StreamLabPresentation
import StreamLabDesignSystem

@MainActor public final class HomeViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    public static func instantiate() -> HomeViewController {
        UIStoryboard(name: "Home", bundle: .module).instantiateViewController(withIdentifier: "Home") as! HomeViewController
    }

    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var statusLabel: UILabel!
    public var store: CatalogStore!
    public var onSelect: ((String) -> Void)?
    private var sections: [(String, [CatalogTitle])] = []
    private var progress: [String: Double] = [:]
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "STREAMLAB"
        StreamLabTheme.configure(statusLabel, style: .body)
        collectionView.backgroundColor = .black
        collectionView.accessibilityIdentifier = "home-catalog"
        collectionView.register(PosterCell.self, forCellWithReuseIdentifier: "Poster")
        collectionView.register(RailHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "Header")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.setCollectionViewLayout(Self.layout(), animated: false)
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        collectionView.refreshControl = refresh
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "새로고침", style: .plain, target: self, action: #selector(reload))
        store.onChange = { [weak self] in self?.render() }
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: HomeViewController, _: UITraitCollection) in
            self.collectionView.setCollectionViewLayout(Self.layout(), animated: false)
        }
    }
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        store.loadHome()
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store.invalidate()
    }
    @objc private func reload() { store.loadHome() }
    private static func layout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { section, environment in
            let accessibility = environment.traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            let hero = section == 0
            let width = hero ? min(environment.container.effectiveContentSize.width - 32, 640) : (accessibility ? 290.0 : 170.0)
            let height = UIFontMetrics(forTextStyle: .headline).scaledValue(for: hero ? 290 : 250, compatibleWith: environment.traitCollection)
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .absolute(width), heightDimension: .absolute(height)), subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 12
            section.contentInsets = .init(top: 0, leading: 16, bottom: 24, trailing: 16)
            section.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60)), elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)]
            return section
        }
    }
    private func render() {
        sections = []
        progress = [:]
        if let snapshot = store.home {
            sections = [("\(store.profile.displayName)님을 위한 오늘의 추천", [snapshot.hero]), ("계속 시청 · 샘플 진도", snapshot.continueWatching.map(\.title))]
            sections += snapshot.rails.map { ($0.title, $0.items) }
            progress = Dictionary(uniqueKeysWithValues: snapshot.continueWatching.map { ($0.id, $0.fraction) })
        }
        statusLabel.text = store.errorMessage ?? (store.loading ? "콘텐츠 불러오는 중…" : nil)
        statusLabel.isHidden = statusLabel.text == nil
        if !store.loading { collectionView.refreshControl?.endRefreshing() }
        collectionView.reloadData()
    }
    public func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { sections[section].1.count }
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Poster", for: indexPath) as! PosterCell
        let title = sections[indexPath.section].1[indexPath.item]
        cell.configure(title, progress: indexPath.section == 1 ? progress[title.id] : nil, hero: indexPath.section == 0)
        return cell
    }
    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! RailHeader
        header.label.text = sections[indexPath.section].0
        return header
    }
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(sections[indexPath.section].1[indexPath.item].id)
    }
}
