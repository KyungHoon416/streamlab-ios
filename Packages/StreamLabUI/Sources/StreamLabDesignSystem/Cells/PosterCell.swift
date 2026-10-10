import UIKit
import StreamLabDomain

@MainActor public final class PosterCell: UICollectionViewCell {
    private let symbol = UIImageView()
    private let nameLabel = UILabel()
    private let metadata = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let gradient = CAGradientLayer()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.layer.insertSublayer(gradient, at: 0)
        symbol.contentMode = .scaleAspectFit
        symbol.tintColor = .white.withAlphaComponent(0.85)
        symbol.setContentHuggingPriority(.defaultLow, for: .vertical)
        StreamLabTheme.configure(nameLabel, style: .headline)
        StreamLabTheme.configure(metadata, style: .caption1)
        progress.progressTintColor = StreamLabTheme.accent
        let stack = UIStackView(arrangedSubviews: [symbol, nameLabel, metadata, progress])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            symbol.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("PosterCell uses registered reusable cells") }
    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = contentView.bounds
        CATransaction.commit()
    }
    public func configure(_ title: CatalogTitle, progress fraction: Double? = nil, hero: Bool = false) {
        let color = UIColor(hue: CGFloat(title.visualSeed % 360) / 360, saturation: 0.65, brightness: 0.46, alpha: 1)
        gradient.colors = [color.cgColor, UIColor(white: 0.07, alpha: 1).cgColor]
        symbol.image = UIImage(systemName: title.kind == .movie ? "film.stack.fill" : "play.rectangle.on.rectangle.fill")
        nameLabel.text = (hero ? "STREAMLAB ORIGINAL\n" : "") + title.name
        metadata.text = "\(title.year) · \(title.rating.rawValue) · \(title.genre)"
        progress.isHidden = fraction == nil
        progress.progress = Float(fraction ?? 0)
        accessibilityLabel = "\(title.name), \(title.rating.rawValue), \(title.genre)" + (fraction.map { ", \(Int($0 * 100))퍼센트 시청" } ?? "")
        accessibilityHint = "콘텐츠 상세 정보 열기"
        accessibilityIdentifier = "title-\(title.id)"
    }
}
