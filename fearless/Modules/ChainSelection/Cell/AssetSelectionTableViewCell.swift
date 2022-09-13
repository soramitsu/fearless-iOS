import UIKit

final class AssetSelectionTableViewCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let checkmarkSize = CGSize(width: 24.0, height: 24.0)
    }

    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.listCheckmarkIcon()
        imageView.tintColor = R.color.colorWhite()
        return imageView
    }()

    let iconImageView = UIImageView()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorLightGray()
        label.font = .p2Paragraph
        return label
    }()

    let stakingTypeLabel: InsettedLabel = {
        let label = InsettedLabel(insets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))
        label.font = .capsTitle
        label.backgroundColor = R.color.colorWhite16()!
        label.layer.cornerRadius = 3
        label.layer.masksToBounds = true
        return label
    }()

    private var viewModel: AssetSelectionTableViewCellModel?

    override func prepareForReuse() {
        super.prepareForReuse()

        viewModel?.icon?.cancel(on: iconImageView)
        viewModel?.removeObserver(self)
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = .clear

        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = R.color.colorCellSelection()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(checkmarkImageView)

        checkmarkImageView.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.checkmarkSize)
        }

        contentView.addSubview(iconImageView)

        iconImageView.snp.makeConstraints { make in
            make.left.equalTo(checkmarkImageView.snp.right).offset(UIConstants.accessoryItemsSpacing)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        let textStackView = UIFactory.default.createVerticalStackView()
        contentView.addSubview(textStackView)
        textStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        let spacingView = UIView()
        let titlesStackView = UIFactory.default.createHorizontalStackView(spacing: UIConstants.minimalOffset)
        titlesStackView.addArrangedSubview(titleLabel)
        titlesStackView.addArrangedSubview(stakingTypeLabel)
        titlesStackView.addArrangedSubview(spacingView)
        textStackView.addArrangedSubview(titlesStackView)
        textStackView.addArrangedSubview(subtitleLabel)

        spacingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stakingTypeLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        stakingTypeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    private func updateSelectionState() {
        checkmarkImageView.isHidden = !(viewModel?.isSelected ?? false)
    }
}

extension AssetSelectionTableViewCell: SelectionItemViewProtocol {
    func bind(viewModel: SelectableViewModelProtocol) {
        guard let iconDetailsViewModel = viewModel as? AssetSelectionTableViewCellModel else {
            return
        }

        self.viewModel = iconDetailsViewModel

        titleLabel.text = iconDetailsViewModel.title
        subtitleLabel.text = iconDetailsViewModel.subtitle

        stakingTypeLabel.text = iconDetailsViewModel.stakingType.title
        stakingTypeLabel.isHidden = iconDetailsViewModel.stakingType.title == nil

        iconImageView.image = nil
        if iconDetailsViewModel.icon == nil {
            iconImageView.image = R.image.allNetworksIcon()
        } else {
            iconDetailsViewModel.icon?.loadImage(
                on: iconImageView,
                targetSize: Constants.iconSize,
                animated: true
            )
        }

        updateSelectionState()

        iconDetailsViewModel.addObserver(self)
    }
}

extension AssetSelectionTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
