import UIKit
import SoraUI

class IconDetailsView: UIView {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    var horizontalSpacing = 8.0 {
        didSet {
            detailsLabel.snp.updateConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(horizontalSpacing)
            }

            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        guard imageView.superview == nil else {
            return
        }

        setupLayout()
    }

    private func setupLayout() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.top.lessThanOrEqualToSuperview()
        }

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(horizontalSpacing)
            make.trailing.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.top.lessThanOrEqualToSuperview()
        }
    }
}
