import UIKit

final class AssetManagementTableCell: UITableViewCell {
    let iconImageView = UIImageView()

    let symbolLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .p1Paragraph
        return label
    }()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        return label
    }()

    let balanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()
        label.font = .h5Title
        label.textAlignment = .right
        return label
    }()

    let fiatBalanceLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorStrokeGray()
        label.font = .p2Paragraph
        label.textAlignment = .right
        return label
    }()

    let switchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorPink()
        switchView.isUserInteractionEnabled = false
        return switchView
    }()

    private var viewModel: AssetManagementTableCellViewModel?

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = nil
        iconImageView.highlightedImage = nil
        viewModel?.assetImage?.cancel(on: iconImageView)
        viewModel = nil
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetManagementTableCellViewModel) {
        self.viewModel = viewModel
        viewModel.assetImage?.loadImage(
            on: iconImageView,
            targetSize: CGSize(width: 32, height: 32),
            animated: true,
            cornerRadius: 16,
            completionHandler: { [weak self, viewModel] result in
                guard let image = try? result.get() else {
                    return
                }
                self?.iconImageView.highlightedImage = image.image.monochrome()
                self?.iconImageView.isHighlighted = viewModel.hidden
            }
        )
        symbolLabel.text = viewModel.assetName
        chainNameLabel.text = viewModel.chainName
        balanceLabel.text = viewModel.balance.amount
        fiatBalanceLabel.text = viewModel.balance.price
        switchView.isOn = !viewModel.hidden

        applyStyle(isOn: !viewModel.hidden, hasGroup: viewModel.hasGroup)
    }

    private func applyStyle(isOn: Bool, hasGroup: Bool) {
        if hasGroup {
            contentView.backgroundColor = R.color.colorBlack02()
        } else {
            contentView.backgroundColor = R.color.colorBlack19()
        }

        if isOn {
            symbolLabel.textColor = R.color.colorWhite()
        } else {
            symbolLabel.textColor = R.color.colorStrokeGray()
        }
    }

    private func setupLayout() {
        let assetTextsContainer = UIFactory.default.createVerticalStackView()
        let balanceTextsContainer = UIFactory.default.createVerticalStackView()

        contentView.snp.makeConstraints { make in
            make.height.equalTo(55)
            make.width.equalToSuperview()
        }

        [
            symbolLabel,
            chainNameLabel
        ].forEach { assetTextsContainer.addArrangedSubview($0) }

        [
            balanceLabel,
            fiatBalanceLabel
        ].forEach { balanceTextsContainer.addArrangedSubview($0) }

        [
            iconImageView,
            assetTextsContainer,
            balanceTextsContainer,
            switchView
        ].forEach { contentView.addSubview($0) }

        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(32)
        }

        assetTextsContainer.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalTo(balanceTextsContainer)
            make.centerY.equalToSuperview()
        }

        balanceTextsContainer.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
        }

        switchView.set(width: 36, height: 21)
        switchView.snp.makeConstraints { make in
            make.leading.equalTo(balanceTextsContainer.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
        }
    }
}
