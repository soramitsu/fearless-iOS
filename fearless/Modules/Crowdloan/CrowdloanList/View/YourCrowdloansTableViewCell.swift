import UIKit

final class YourCrowdloansTableViewCell: UITableViewCell {
    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconTabCrowloan()?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let navigationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconSmallArrow()
        imageView.contentMode = .center
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        backgroundColor = .clear
        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()
    }

    private func setupLayout() {
        contentView.addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16.0)
            make.size.equalTo(24)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(navigationImageView)

        navigationImageView.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16.0)
            make.size.equalTo(24)
            make.centerY.equalToSuperview()
        }

        addSubview(titleLabel)
        addSubview(detailsLabel)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(16.0)
            make.top.bottom.equalToSuperview().inset(16.0)
        }

        detailsLabel.snp.makeConstraints { make in
            make.trailing.equalTo(navigationImageView.snp.leading).offset(-8.0)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8.0)
        }
    }

    func bind(details: String, for locale: Locale) {
        titleLabel.text = R.string.localizable.crowdloanYouContributionsTitle(
            preferredLanguages: locale.rLanguages
        )

        detailsLabel.text = details
    }
}
