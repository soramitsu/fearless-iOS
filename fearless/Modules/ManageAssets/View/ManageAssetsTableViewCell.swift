import UIKit

protocol ManageAssetsTableViewCellDelegate: AnyObject {
    func assetEnabledSwitcherValueChanged()
    func addAccountButtonClicked()
}

class ManageAssetsTableViewCell: UITableViewCell {
    private weak var delegate: ManageAssetsTableViewCellDelegate?

    private enum LayoutConstants {
        static let iconSize: CGFloat = 24
        static let switcherHeight: CGFloat = 21
        static let switcherWidth: CGFloat = 36
        static let optionsViewHeight: CGFloat = 16
    }

    let chainIconImageView = UIImageView()

    let chainNameLabel: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorWhite()
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return label
    }()

    let tokenBalanceLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorTransparentText()
        return label
    }()

    let switcher: UISwitch = {
        let switcher = UISwitch()
        switcher.onTintColor = R.color.colorPink()
        return switcher
    }()

    let dragButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconDrag(), for: .normal)
        return button
    }()

    let chainOptionsView = UIFactory.default.createChainOptionsView()

    private var accountMissingHintView: HintView = {
        let view = UIFactory.default.createHintView()
        view.iconView.image = R.image.iconWarning()
        return view
    }()

    private var addMissingAccountButton: UIButton = {
        let button = UIButton()
        button.titleLabel?.font = .p1Paragraph
        button.setTitleColor(R.color.colorPink(), for: .normal)
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        chainIconImageView.kf.cancelDownloadTask()

        chainOptionsView.arrangedSubviews.forEach { subview in
            chainOptionsView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
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

        selectionStyle = .none

        switcher.addTarget(
            self,
            action: #selector(switcherValueChanged),
            for: .valueChanged
        )

        addMissingAccountButton.addTarget(
            self,
            action: #selector(addMissingAccountButtonClicked),
            for: .touchUpInside
        )
    }

    @objc private func switcherValueChanged() {
        delegate?.assetEnabledSwitcherValueChanged()
    }

    @objc private func addMissingAccountButtonClicked() {
        delegate?.addAccountButtonClicked()
    }

    private func setupLayout() {
        contentView.addSubview(chainIconImageView)
        contentView.addSubview(chainNameLabel)
        contentView.addSubview(chainOptionsView)
        contentView.addSubview(tokenBalanceLabel)
        contentView.addSubview(switcher)
        contentView.addSubview(dragButton)
        contentView.addSubview(addMissingAccountButton)
        contentView.addSubview(accountMissingHintView)

        chainIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }

        dragButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LayoutConstants.iconSize)
        }

        switcher.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(
                UIConstants.bigOffset
                    + UIConstants.defaultOffset
                    + LayoutConstants.iconSize
            )
            make.centerY.equalToSuperview()
        }

        chainNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(chainIconImageView.snp.trailing).offset(UIConstants.bigOffset)
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
        }

        chainOptionsView.snp.makeConstraints { make in
            make.leading.equalTo(chainNameLabel.snp.trailing).offset(UIConstants.minimalOffset)
            make.trailing.greaterThanOrEqualTo(switcher.snp.leading).inset(UIConstants.bigOffset).priority(.low)
            make.height.equalTo(LayoutConstants.optionsViewHeight)
            make.centerY.equalTo(chainNameLabel.snp.centerY)
        }

        tokenBalanceLabel.snp.makeConstraints { make in
            make.leading.equalTo(chainNameLabel.snp.leading)
            make.top.equalTo(chainNameLabel.snp.bottom).offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        addMissingAccountButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.centerY.equalToSuperview()
            make.top.bottom.equalToSuperview()
        }

        accountMissingHintView.snp.makeConstraints { make in
            make.leading.equalTo(chainNameLabel.snp.leading)
            make.top.equalTo(chainNameLabel.snp.bottom).offset(UIConstants.minimalOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        switcher.set(
            width: LayoutConstants.switcherWidth,
            height: LayoutConstants.switcherHeight
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        switcher.set(
            width: LayoutConstants.switcherWidth,
            height: LayoutConstants.switcherHeight
        )
    }

    func bind(to viewModel: ManageAssetsTableViewCellModel) {
        delegate = viewModel
        viewModel.imageViewModel?.cancel(on: chainIconImageView)

        chainNameLabel.text = viewModel.assetName?.capitalized
        tokenBalanceLabel.text = viewModel.balanceString
        switcher.isOn = viewModel.assetEnabled

        viewModel.imageViewModel?.loadBalanceListIcon(
            on: chainIconImageView,
            animated: false
        )

        if let options = viewModel.options, !options.isEmpty {
            options.forEach { option in
                let view = ChainOptionsView()
                view.bind(to: option)

                chainOptionsView.addArrangedSubview(view)
            }
        }

        switcher.set(
            width: LayoutConstants.switcherWidth,
            height: LayoutConstants.switcherHeight
        )

        tokenBalanceLabel.isHidden = viewModel.accountMissing
        dragButton.isHidden = viewModel.accountMissing
        switcher.isHidden = viewModel.accountMissing
        accountMissingHintView.isHidden = !viewModel.accountMissing
        addMissingAccountButton.isHidden = !viewModel.accountMissing
        accountMissingHintView.setIconHidden(viewModel.chainUnused)

        accountMissingHintView.titleLabel.text = R.string.localizable.manageAssetsAccountMissingText(
            preferredLanguages: viewModel.locale?.rLanguages
        )
        addMissingAccountButton.setTitle(
            R.string.localizable.accountsAddAccount(
                preferredLanguages: viewModel.locale?.rLanguages),
            for: .normal
        )

        setDeactivated(viewModel.cellInactive)
    }
}

extension ManageAssetsTableViewCell: DeactivatableView {
    var deactivatableViews: [UIView] {
        [chainNameLabel, accountMissingHintView.titleLabel]
    }

    var deactivatedAlpha: CGFloat {
        0.5
    }
}
