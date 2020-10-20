import UIKit

final class ApplicationStatusView: UIView {
    let titleLabel = UILabel()

    var contentInsets = UIEdgeInsets.zero {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        titleLabel.backgroundColor = .clear
        titleLabel.textAlignment = .center

        addSubview(titleLabel)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size = titleLabel.sizeThatFits(bounds.size)

        let origin = CGPoint(x: bounds.size.width / 2.0 - size.width / 2.0 + contentInsets.left - contentInsets.right,
                             y: bounds.size.height / 2.0 - size.height / 2.0 + contentInsets.top - contentInsets.bottom)

        titleLabel.frame = CGRect(origin: origin, size: size)
    }
}
