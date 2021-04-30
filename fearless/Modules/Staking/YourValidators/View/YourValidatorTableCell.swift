import Foundation
import FearlessUtils

class YourValidatorTableCell: UITableViewCell {
    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = R.color.colorWhite()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()!
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        return label
    }()

    let warningImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarning()
        return imageView
    }()

    let infoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconInfo()
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }

        contentView.addSubview(infoImageView)
        infoImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(warningImageView)
        warningImageView.snp.makeConstraints { make in
            make.trailing.equalTo(infoImageView.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8.0)
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(warningImageView.snp.leading).offset(-8.0)
        }

        contentView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(8.0)
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.trailing.lessThanOrEqualTo(warningImageView.snp.leading).offset(-8.0)
        }
    }

    func bind(viewModel: YourValidatorViewModel, for locale: Locale) {
        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.text = viewModel.address
            titleLabel.lineBreakMode = .byTruncatingMiddle
        }

        warningImageView.isHidden = !viewModel.shouldHaveWarning

        let amountTitle = viewModel.amount?.value(for: locale)
        let isDetailsEmpty = amountTitle?.isEmpty ?? true

        if let details = amountTitle {
            detailsLabel.text = R.string.localizable.stakingYourNominatedFormat(
                details,
                preferredLanguages: locale.rLanguages
            )
        } else {
            detailsLabel.text = nil
        }

        iconView.bind(icon: viewModel.icon)

        titleLabel.snp.updateConstraints { make in
            if isDetailsEmpty {
                make.top.equalToSuperview().inset(16)
            } else {
                make.top.equalToSuperview().inset(8)
            }
        }
    }
}
