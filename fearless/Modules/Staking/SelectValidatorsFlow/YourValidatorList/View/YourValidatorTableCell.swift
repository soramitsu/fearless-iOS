import Foundation
import SSFUtils

class YourValidatorTableCell: UITableViewCell {
    private enum LayoutConstants {
        static let infoIconSize: CGFloat = 14
        static let checkmarkIconSize: CGFloat = 20
    }

    let iconView: UIImageView = {
        let view = UIImageView()
        view.image = R.image.iconListSelectionOn()
        return view
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h6Title
        label.textColor = R.color.colorWhite()!
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return label
    }()

    let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return label
    }()

    let warningImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconWarning()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return imageView
    }()

    let errorImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconErrorFilled()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return imageView
    }()

    let infoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconInfoGrayFilled()
        return imageView
    }()

    let apyLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p2Paragraph
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return label
    }()

    let mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.layoutMargins = UIEdgeInsets(
            top: 8,
            left: UIConstants.horizontalInset,
            bottom: 8,
            right: UIConstants.horizontalInset
        )
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillProportionally
        stackView.spacing = 12
        return stackView
    }()

    let labelsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        return stackView
    }()

    let iconsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 9.0
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = R.color.colorBlack19()
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
        contentView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.offset12)
            make.bottom.equalToSuperview().inset(UIConstants.offset12)
        }

        mainStackView.addArrangedSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(LayoutConstants.checkmarkIconSize)
        }

        mainStackView.addArrangedSubview(labelsStackView)

        labelsStackView.addArrangedSubview(titleLabel)
        labelsStackView.addArrangedSubview(detailsLabel)
        labelsStackView.addArrangedSubview(apyLabel)

        mainStackView.addArrangedSubview(iconsStackView)

        iconsStackView.addArrangedSubview(warningImageView)
        iconsStackView.addArrangedSubview(errorImageView)

        mainStackView.addArrangedSubview(infoImageView)
        infoImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.infoIconSize)
        }
        errorImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.infoIconSize)
        }
        warningImageView.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.infoIconSize)
        }

        mainStackView.setCustomSpacing(12, after: iconView)
        mainStackView.setCustomSpacing(8.0, after: labelsStackView)
        mainStackView.setCustomSpacing(13.0, after: iconsStackView)

        labelsStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        iconsStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        labelsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        iconsStackView.setContentHuggingPriority(.required, for: .horizontal)
        errorImageView.setContentHuggingPriority(.required, for: .horizontal)
    }

    func bind(viewModel: YourValidatorViewModel, for _: Locale) {
        if let name = viewModel.name {
            titleLabel.lineBreakMode = .byTruncatingTail
            titleLabel.text = name.uppercased()
        } else {
            titleLabel.text = viewModel.address
            titleLabel.lineBreakMode = .byTruncatingMiddle
        }

        detailsLabel.text = viewModel.staked

        warningImageView.isHidden = !viewModel.shouldHaveWarning
        errorImageView.isHidden = !viewModel.shouldHaveError

        if let apy = viewModel.apy {
            apyLabel.isHidden = false
            apyLabel.attributedText = apy
        } else {
            apyLabel.isHidden = true
            apyLabel.text = nil
        }
    }
}
