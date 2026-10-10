import UIKit
import StreamLabDomain
import StreamLabPresentation
import StreamLabDesignSystem

@MainActor public final class DetailViewController: UIViewController {
    public static func instantiate() -> DetailViewController {
        UIStoryboard(name: "Detail", bundle: .module).instantiateViewController(withIdentifier: "Detail") as! DetailViewController
    }

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var metadataLabel: UILabel!
    @IBOutlet private weak var synopsisLabel: UILabel!
    @IBOutlet private weak var playbackButton: UIButton!
    public var store: CatalogStore!
    public var titleID = ""
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "콘텐츠 상세"
        StreamLabTheme.configure(titleLabel, style: .largeTitle)
        StreamLabTheme.configure(metadataLabel, style: .subheadline)
        StreamLabTheme.configure(synopsisLabel, style: .body)
        titleLabel.accessibilityTraits = .header
        titleLabel.accessibilityIdentifier = "detail-title"
        StreamLabTheme.button(playbackButton, title: "재생 · Phase 2 예정")
        playbackButton.accessibilityIdentifier = "phase2-playback"
        playbackButton.addAction(UIAction { [weak self] _ in
            let alert = UIAlertController(title: "Phase 2 예정", message: "Phase 1은 탐색 기능을 제공합니다. 실제 영상 재생은 아직 구현되지 않았습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            self?.present(alert, animated: true)
        }, for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "다시 시도", style: .plain, target: self, action: #selector(reload))
        store.onChange = { [weak self] in self?.render() }
    }
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if store.resume() != nil { return }
        if store.detail == nil { reload() }
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        store.suspend()
    }
    @objc private func reload() { store.loadDetail(id: titleID) }
    private func render() {
        navigationItem.rightBarButtonItem?.isEnabled = !store.loading
        playbackButton.isHidden = store.detail == nil
        titleLabel.text = store.detail?.name ?? (store.loading ? "불러오는 중…" : "콘텐츠를 열 수 없습니다")
        if let title = store.detail {
            metadataLabel.text = "\(title.year) · \(title.rating.rawValue) · \(title.typeLabel) · \(title.durationMinutes)분\n\(title.genre)"
            synopsisLabel.text = title.synopsis + "\n\n오리지널 Mock 콘텐츠 · 실제 상용 영상이 아닙니다."
        } else {
            metadataLabel.text = nil
            synopsisLabel.text = store.errorMessage
        }
    }
}
