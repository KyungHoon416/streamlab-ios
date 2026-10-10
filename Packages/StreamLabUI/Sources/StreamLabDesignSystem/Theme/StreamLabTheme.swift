import UIKit
import StreamLabDomain

@MainActor public enum StreamLabTheme {
    public static let accent = UIColor(red: 0.90, green: 0.04, blue: 0.10, alpha: 1)
    public static func configure(_ label: UILabel, style: UIFont.TextStyle) {
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = .white
    }
    public static func button(_ button: UIButton, title: String) {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = accent
        config.baseForegroundColor = .white
        config.contentInsets = .init(top: 16, leading: 20, bottom: 16, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in
            var output = input
            output.font = UIFont.preferredFont(forTextStyle: .headline)
            return output
        }
        button.configuration = config
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
    }
}
