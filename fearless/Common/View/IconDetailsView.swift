import UIKit
import SoraUI

class IconDetailsView: UIView {
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p2Paragraph
        label.numberOfLines = 0
        return label
    }()

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            detailsLabel.snp.updateConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(horizontalSpacing)
            }

            setNeedsLayout()
        }
    }

    var iconWidth: CGFloat = 16.0 {
        didSet {
            imageView.snp.updateConstraints { make in
                make.width.equalTo(iconWidth)
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
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(iconWidth)
        }

        addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(imageView.snp.trailing).offset(horizontalSpacing)
            make.trailing.top.bottom.equalToSuperview()
        }
    }
}
