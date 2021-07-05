import UIKit
import SoraUI

class StatusRowView: BaseRowView {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        label.textAlignment = .right
        return label
    }()

    let selectionIndicatorView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconInfo()
        return imageView
    }()

    let statusIndicatorView: RoundedView = {
        let view = RoundedView()
        view.cornerRadius = 4
        return view
    }()

    var locale = Locale.current {
        didSet {
            applyLocale()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocale()
    }

    private func applyLocale() {
        titleLabel.text = R.string.localizable.commonStatus(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        contentView?.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        contentView?.addSubview(selectionIndicatorView)
        selectionIndicatorView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(6.0)
            make.centerY.equalToSuperview()
            make.size.equalTo(14.0)
        }

        contentView?.addSubview(statusIndicatorView)
        statusIndicatorView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(8.0)
        }

        contentView?.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.trailing.equalTo(statusIndicatorView.snp.leading).offset(-12.0)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(selectionIndicatorView.snp.trailing).offset(12.0)
        }
    }
}
