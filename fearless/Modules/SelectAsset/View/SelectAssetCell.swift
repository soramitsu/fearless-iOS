import UIKit

final class SelectAssetCell: UITableViewCell {
    private enum Constants {
        static let iconSize = CGSize(width: 32.0, height: 32.0)
        static let checkmarkSize = CGSize(width: 20.0, height: 20.0)
    }

    let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconCheckMark()
        return imageView
    }()

    let iconImageView = UIImageView()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .h5Title
        return label
    }()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.font = .p1Paragraph
        return label
    }()

    let balanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white
        label.font = .h5Title
        label.textAlignment = .right
        return label
    }()

    let fiatBalanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p1Paragraph
        label.textAlignment = .right
        return label
    }()

    private var viewModel: SelectAssetCellViewModel?

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
        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(Constants.iconSize)
        }

        let leftTextStackView = UIFactory.default.createVerticalStackView()
        contentView.addSubview(leftTextStackView)
        leftTextStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.equalTo(iconImageView.snp.trailing).offset(UIConstants.accessoryItemsSpacing)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
        leftTextStackView.addArrangedSubview(nameLabel)
        leftTextStackView.addArrangedSubview(symbolLabel)

        let rightTextStackView = UIFactory.default.createVerticalStackView()
        contentView.addSubview(rightTextStackView)
        rightTextStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview().offset(-UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }
        rightTextStackView.addArrangedSubview(fiatBalanceLabel)
        rightTextStackView.addArrangedSubview(balanceLabel)
    }

    private func updateSelectionState() {
//        checkmarkImageView.isHidden = !(viewModel?.isSelected ?? false)
    }
}

extension SelectAssetCell: SelectionItemViewProtocol {
    func bind(viewModel: SelectableViewModelProtocol) {
        guard let selectAssetCellViewModel = viewModel as? SelectAssetCellViewModel else {
            return
        }
        self.viewModel = selectAssetCellViewModel

        nameLabel.text = selectAssetCellViewModel.name
        symbolLabel.text = selectAssetCellViewModel.symbol
        balanceLabel.text = selectAssetCellViewModel.balanceString
        fiatBalanceLabel.text = selectAssetCellViewModel.fiatBalanceString
        iconImageView.image = nil
        if selectAssetCellViewModel.icon == nil {
            iconImageView.image = R.image.allNetworksIcon()
        } else {
            selectAssetCellViewModel.icon?.loadImage(
                on: iconImageView,
                targetSize: Constants.iconSize,
                animated: true
            )
        }
        updateSelectionState()
        selectAssetCellViewModel.addObserver(self)
    }
}

extension SelectAssetCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
