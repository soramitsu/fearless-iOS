import UIKit
import SoraUI

class IconTitleValueView: UIView {
    enum IconPosition {
        case left
        case right
    }

    private var iconPosition: IconPosition = .right

    let imageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = UIFont.p1Paragraph
        return label
    }()

    let borderView = UIFactory.default.createBorderedContainerView()

    init(iconPosition: IconPosition) {
        self.iconPosition = iconPosition

        super.init(frame: .zero)

        setupLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(borderView)
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(valueLabel)

        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        switch iconPosition {
        case .left:
            imageView.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
                make.size.equalTo(16.0)
            }

            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(imageView.snp.trailing).offset(UIConstants.defaultOffset)
                make.centerY.equalToSuperview()
            }

            valueLabel.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.defaultOffset)
            }
        case .right:

            titleLabel.snp.makeConstraints { make in
                make.leading.equalToSuperview()
                make.centerY.equalToSuperview()
            }

            valueLabel.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(UIConstants.defaultOffset)
            }

            imageView.snp.makeConstraints { make in
                make.leading.equalTo(valueLabel.snp.trailing).offset(UIConstants.defaultOffset)
                make.trailing.centerY.equalToSuperview()
                make.size.equalTo(16.0)
            }
        }
    }
}
