import UIKit
import StreamLabDomain

private enum Theme {
    static let background = UIColor(red: 0.045, green: 0.05, blue: 0.07, alpha: 1)
    static let accent = UIColor(red: 0.91, green: 0.14, blue: 0.18, alpha: 1)
}

private func pin(_ child: UIView, to parent: UIView) {
    child.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        child.topAnchor.constraint(equalTo: parent.topAnchor),
        child.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
        child.trailingAnchor.constraint(equalTo: parent.trailingAnchor)
    ])
}

final class ProfileViewController: UIViewController {
    var onSelect: ((ViewerProfile) -> Void)?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        let logo = UILabel()
        logo.text = "STREAMLAB"
        logo.textAlignment = .center
        logo.textColor = Theme.accent
        logo.font = .systemFont(ofSize: 29, weight: .black)
        let title = UILabel()
        title.text = "누가 시청하나요?"
        title.textAlignment = .center
        title.textColor = .white
        title.font = .preferredFont(forTextStyle: .title2)
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 12
        for (index, profile) in ViewerProfile.demo.enumerated() {
            var configuration = UIButton.Configuration.filled()
            configuration.title = profile.displayName
            configuration.image = UIImage(systemName: profile.avatarSymbol)
            configuration.imagePlacement = .top
            configuration.imagePadding = 12
            configuration.baseBackgroundColor = profile.kind == .kids ? .systemOrange : .systemIndigo
            let button = UIButton(configuration: configuration)
            button.tag = index
            button.accessibilityLabel = "\(profile.displayName) 프로필 선택"
            button.addTarget(self, action: #selector(profileTapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
        }
        let stack = UIStackView(arrangedSubviews: [logo, title, row])
        stack.axis = .vertical
        stack.spacing = 30
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            row.heightAnchor.constraint(equalToConstant: 120)
        ])
    }
    @objc private func profileTapped(_ sender: UIButton) {
        guard ViewerProfile.demo.indices.contains(sender.tag) else { return }
        onSelect?(ViewerProfile.demo[sender.tag])
    }
}

final class HomeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSwitch: (() -> Void)?
    private var profile: ViewerProfile?
    private var repository: (any CatalogRepository)?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var snapshot: HomeSnapshot?
    private var rows: [(String, [CatalogTitle])] = []
    private let table = UITableView(frame: .zero, style: .grouped)

    func configure(profile: ViewerProfile, repository: any CatalogRepository) {
        self.profile = profile
        self.repository = repository
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "STREAMLAB"
        view.backgroundColor = Theme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "프로필 변경", style: .plain, target: self, action: #selector(switchProfile))
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = Theme.background
        table.register(UITableViewCell.self, forCellReuseIdentifier: "catalog")
        view.addSubview(table)
        pin(table, to: view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let profile, let repository else { return }
        generation += 1
        let version = generation
        task?.cancel()
        task = Task { [weak self] in
            do {
                let result = try await repository.home(profile: profile)
                guard let self, version == self.generation, !Task.isCancelled else { return }
                self.snapshot = result
                self.rows = [("추천 작품", [result.hero])]
                  + (result.continueWatching.isEmpty ? [] : [("계속 시청", result.continueWatching.map(\.title))])
                  + result.rails.map { ($0.title, $0.items) }
                self.table.reloadData()
            } catch is CancellationError {
            } catch {
                guard let self, version == self.generation else { return }
                self.navigationItem.prompt = "홈 콘텐츠를 불러올 수 없습니다."
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        generation += 1
        task?.cancel()
    }
    @objc private func switchProfile() { onSwitch?() }
    func numberOfSections(in tableView: UITableView) -> Int { rows.count }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows[section].1.count }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { rows[section].0 }
    func tableView(_ tableView: UITableView, cellForRowAt path: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "catalog", for: path)
        let item = rows[path.section].1[path.row]
        var config = cell.defaultContentConfiguration()
        config.text = item.name
        config.secondaryText = "\(item.genre) · \(item.rating.rawValue) · \(item.year)"
        config.image = UIImage(systemName: "film.fill")
        config.imageProperties.tintColor = Theme.accent
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = Theme.background
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt path: IndexPath) {
        showDetail(rows[path.section].1[path.row])
    }
    private func showDetail(_ item: CatalogTitle) {
        let detail = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        detail.item = item
        navigationController?.pushViewController(detail, animated: true)
    }
}

final class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private var profile: ViewerProfile?
    private var repository: (any CatalogRepository)?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var items: [CatalogTitle] = []
    private var cursor: String?
    private var busy = false
    private let table = UITableView()

    func configure(profile: ViewerProfile, repository: any CatalogRepository) {
        self.profile = profile
        self.repository = repository
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "검색"
        let search = UISearchController(searchResultsController: nil)
        search.searchResultsUpdater = self
        search.obscuresBackgroundDuringPresentation = false
        navigationItem.searchController = search
        navigationItem.hidesSearchBarWhenScrolling = false
        table.dataSource = self
        table.delegate = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "result")
        view.addSubview(table)
        pin(table, to: view)
        reload(query: "")
    }
    func updateSearchResults(for searchController: UISearchController) {
        reload(query: searchController.searchBar.text ?? "")
    }
    private func reload(query: String) {
        guard let profile, let repository else { return }
        generation += 1
        let current = generation
        task?.cancel()
        busy = true
        items = []
        cursor = nil
        table.reloadData()
        task = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                let page = try await repository.search(query, profile: profile, after: nil, limit: 24)
                guard let self, current == self.generation, !Task.isCancelled else { return }
                self.items = page.items
                self.cursor = page.nextCursor
                self.busy = false
                self.table.reloadData()
            } catch is CancellationError {
            } catch {
                guard let self, current == self.generation else { return }
                self.busy = false
                self.navigationItem.prompt = "검색 요청이 실패했습니다."
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        generation += 1
        task?.cancel()
        busy = false
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count + (cursor == nil ? 0 : 1) }
    func tableView(_ tableView: UITableView, cellForRowAt path: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "result", for: path)
        var config = cell.defaultContentConfiguration()
        if path.row == items.count {
            config.text = busy ? "로딩 중..." : "다음 결과 불러오기"
        } else {
            let item = items[path.row]
            config.text = item.name
            config.secondaryText = "\(item.genre) · \(item.rating.rawValue)"
        }
        cell.contentConfiguration = config
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt path: IndexPath) {
        if path.row == items.count { loadNext(); return }
        let screen = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DetailViewController") as! DetailViewController
        screen.item = items[path.row]
        navigationController?.pushViewController(screen, animated: true)
    }
    private func loadNext() {
        guard !busy, let profile, let repository, let cursor else { return }
        busy = true
        let current = generation
        let text = navigationItem.searchController?.searchBar.text ?? ""
        task = Task { [weak self] in
            do {
                let page = try await repository.search(text, profile: profile, after: cursor, limit: 24)
                guard let self, current == self.generation, !Task.isCancelled else { return }
                var ids = Set(self.items.map(\.id))
                self.items.append(contentsOf: page.items.filter { ids.insert($0.id).inserted })
                self.cursor = page.nextCursor
                self.busy = false
                self.table.reloadData()
            } catch is CancellationError {
            } catch {
                guard let self, current == self.generation else { return }
                self.busy = false
                self.navigationItem.prompt = "추가 결과를 불러오지 못했습니다."
            }
        }
    }
}

final class DetailViewController: UIViewController {
    var item: CatalogTitle?
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let item else { return }
        title = item.name
        view.backgroundColor = Theme.background
        let heading = UILabel()
        heading.text = item.name
        heading.font = .preferredFont(forTextStyle: .largeTitle)
        heading.numberOfLines = 0
        heading.textColor = .white
        let info = UILabel()
        info.text = "\(item.year) · \(item.genre) · \(item.rating.rawValue)"
        info.textColor = .secondaryLabel
        let summary = UILabel()
        summary.text = item.synopsis
        summary.numberOfLines = 0
        summary.textColor = .white
        let button = UIButton(type: .system)
        button.setTitle("▶ 재생 (Phase 2 예정)", for: .normal)
        button.tintColor = Theme.accent
        button.addTarget(self, action: #selector(showNotice), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [heading, info, summary, button])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }
    @objc private func showNotice() {
        let alert = UIAlertController(title: "아직 구현되지 않았습니다", message: "AVPlayer/HLS 재생은 Phase 2에서 구현합니다.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}
