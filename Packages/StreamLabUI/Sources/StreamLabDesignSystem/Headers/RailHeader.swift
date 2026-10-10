import UIKit

@MainActor public final class RailHeader: UICollectionReusableView {
    public let label = UILabel()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        StreamLabTheme.configure(label, style: .title2)
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    required init?(coder: NSCoder) { fatalError("RailHeader uses registered supplementary views") }
}
