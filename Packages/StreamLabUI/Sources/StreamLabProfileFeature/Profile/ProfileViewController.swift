import UIKit
import StreamLabDomain
import StreamLabDesignSystem

@MainActor public final class ProfileViewController: UIViewController {
    public static func instantiate() -> ProfileViewController {
        UIStoryboard(name: "Profile", bundle: .module).instantiateViewController(withIdentifier: "Profiles") as! ProfileViewController
    }

    @IBOutlet private weak var headingLabel: UILabel!
    @IBOutlet private weak var alexButton: UIButton!
    @IBOutlet private weak var jamieButton: UIButton!
    @IBOutlet private weak var kidsButton: UIButton!
    public var onSelect: ((ViewerProfile) -> Void)?
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        StreamLabTheme.configure(headingLabel, style: .largeTitle)
        headingLabel.text = "STREAMLAB\n누가 시청하나요?"
        headingLabel.accessibilityTraits = .header
        for (index, button) in [alexButton!, jamieButton!, kidsButton!].enumerated() {
            let profile = ViewerProfile.demo[index]
            StreamLabTheme.button(button, title: profile.displayName + (profile.kind == .kids ? " · 키즈" : ""))
            button.configuration?.image = UIImage(systemName: profile.avatarSymbol)
            button.configuration?.imagePadding = 12
            button.accessibilityIdentifier = "profile-\(profile.id)"
            button.addAction(UIAction { [weak self] _ in self?.onSelect?(profile) }, for: .touchUpInside)
        }
    }
}
