import UIKit
import SoraUI

class TitleStatusView: UIView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let indicatorView: RoundedView = {
        let view = RoundedView()
        view.cornerRadius = 4.0
        return view
    }()

    var indicatorColor: UIColor {
        get {
            indicatorView.fillColor
        }

        set {
            indicatorView.fillColor = newValue
        }
    }

    var spacing: CGFloat = 12 {
        didSet {
            indicatorView.snp.updateConstraints { make in
                make.leading.equalTo(titleLabel.snp.trailing).offset(spacing)
            }

            invalidateIntrinsicContentSize()

            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    override var intrinsicContentSize: CGSize {
        let titleSize = titleLabel.intrinsicContentSize
        let indicatorSize = 2 * indicatorView.cornerRadius

        return CGSize(
            width: titleSize.width + spacing + indicatorSize,
            height: max(titleSize.height, indicatorSize)
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        addSubview(indicatorView)
        indicatorView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(spacing)
            make.trailing.centerY.equalToSuperview()
            make.height.equalTo(2 * indicatorView.cornerRadius)
        }
    }
}
