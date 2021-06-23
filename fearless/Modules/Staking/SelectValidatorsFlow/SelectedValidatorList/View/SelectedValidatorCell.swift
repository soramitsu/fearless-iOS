import UIKit
import FearlessUtils

class SelectedValidatorCell: UITableViewCell {
    let iconView: PolkadotIconView = {
        let view = PolkadotIconView()
        view.backgroundColor = .clear
        view.fillColor = R.color.colorWhite()!
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textAlignment = .right
        label.textColor = R.color.colorWhite()
        return label
    }()

    let infoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconInfo()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
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
        separatorInset = .init(
            top: 0,
            left: UIConstants.horizontalInset,
            bottom: 0,
            right: UIConstants.horizontalInset
        )

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorHighlightedAccent()!
    }

    private func setupLayout() {
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }

        contentView.addSubview(infoImageView)
        infoImageView.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
        }

        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(12)
            make.top.bottom.equalToSuperview().inset(16)
        }

        contentView.addSubview(detailsLabel)
        detailsLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(16)
            make.trailing.equalTo(infoImageView.snp.leading).offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    func bind(viewModel: SelectedValidatorCellViewModel) {
        if let icon = viewModel.icon {
            iconView.bind(icon: icon)
        }

        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name
        } else {
            titleLabel.lineBreakMode = .byTruncatingMiddle
            titleLabel.text = viewModel.address
        }

        detailsLabel.text = viewModel.details
    }
}
