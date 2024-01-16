import UIKit
import CommonWallet
import SSFUtils

final class WalletTransactionDetailsViewLayout: UIView {
    lazy var navigationBar: BaseNavigationBar = {
        let navBar = BaseNavigationBar()
        navBar.set(.present)
        return navBar
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let extrinsicHashView = UIFactory.default.createAccountView(for: .options, filled: false)
    let senderView = UIFactory.default.createAccountView(for: .options, filled: false)
    let receiverView = UIFactory.default.createAccountView(for: .options, filled: false)
    let statusView = UIFactory.default.createIconTitleValueView(iconPosition: .right)
    let dateView = UIFactory.default.createTitleValueView()
    let amountView = UIFactory.default.createTitleValueView()
    let moduleView = UIFactory.default.createTitleValueView()
    let callView = UIFactory.default.createTitleValueView()
    let eraView = UIFactory.default.createTitleValueView()
    let slashView = UIFactory.default.createTitleValueView()
    let rewardView = UIFactory.default.createTitleValueView()
    let feeView = UIFactory.default.createTitleValueView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(to viewModel: WalletTransactionDetailsViewModel) {
        extrinsicHashView.isHidden = viewModel.extrinsicHash.count == 0
        extrinsicHashView.subtitleLabel?.text = viewModel.extrinsicHash
        statusView.valueLabel.text = viewModel.status
        dateView.valueLabel.text = viewModel.dateString
        statusView.imageView.image = viewModel.statusIcon

        switch viewModel.transactionType {
        case .incoming, .outgoing:
            if let transferViewModel = viewModel as? TransferTransactionDetailsViewModel {
                bindTransfer(viewModel: transferViewModel)
            }
        case .reward:
            if let rewardViewModel = viewModel as? RewardTransactionDetailsViewModel {
                bindReward(viewModel: rewardViewModel)
            }
        case .slash:
            if let slashViewModel = viewModel as? SlashTransactionDetailsViewModel {
                bindSlash(viewModel: slashViewModel)
            }
        case .extrinsic:
            if let extrinsicViewModel = viewModel as? ExtrinsicTransactionDetailsViewModel {
                bindExtrinsic(viewModel: extrinsicViewModel)
            }
        case .swap, .unused, .bridge:
            break
        }
    }

    private func bindTransfer(viewModel: TransferTransactionDetailsViewModel) {
        moduleView.isHidden = true
        callView.isHidden = true
        eraView.isHidden = true
        slashView.isHidden = true
        rewardView.isHidden = true

        receiverView.subtitleLabel?.text = viewModel.to
        senderView.subtitleLabel?.text = viewModel.from
        amountView.valueLabel.text = viewModel.amount
        feeView.valueLabel.text = viewModel.fee

        if let from = viewModel.from {
            if let icon = try? UniversalIconGenerator().generateFromAddress(from) {
                senderView.iconImage = icon.imageWithFillColor(
                    UIColor.black,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            }
        }

        if let to = viewModel.to {
            if let icon = try? UniversalIconGenerator().generateFromAddress(to) {
                receiverView.iconImage = icon.imageWithFillColor(
                    UIColor.black,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            }
        }
    }

    private func bindReward(viewModel: RewardTransactionDetailsViewModel) {
        amountView.isHidden = true

        feeView.isHidden = true
        moduleView.isHidden = true
        callView.isHidden = true
        slashView.isHidden = true
        senderView.isHidden = true

        receiverView.isHidden = viewModel.validator.isNullOrEmpty
        extrinsicHashView.titleLabel.text = R.string.localizable.stakingCommonEventId(preferredLanguages: locale.rLanguages)
        receiverView.titleLabel.text = R.string.localizable.stakingCommonValidator(preferredLanguages: locale.rLanguages)

        eraView.valueLabel.text = viewModel.era
        rewardView.valueLabel.text = viewModel.reward
        receiverView.subtitleLabel?.text = viewModel.validator

        if let validator = viewModel.validator {
            if let icon = try? UniversalIconGenerator().generateFromAddress(validator) {
                receiverView.iconImage = icon.imageWithFillColor(
                    UIColor.black,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            }
        }
    }

    private func bindSlash(viewModel: SlashTransactionDetailsViewModel) {
        amountView.isHidden = true

        feeView.isHidden = true
        moduleView.isHidden = true
        callView.isHidden = true
        rewardView.isHidden = true

        receiverView.isHidden = viewModel.validator?.count == 0

        receiverView.titleLabel.text = R.string.localizable.stakingCommonValidator(preferredLanguages: locale.rLanguages)

        eraView.valueLabel.text = viewModel.era
        slashView.valueLabel.text = viewModel.slash
        receiverView.subtitleLabel?.text = viewModel.validator

        if let validator = viewModel.validator {
            if let icon = try? UniversalIconGenerator().generateFromAddress(validator) {
                receiverView.iconImage = icon.imageWithFillColor(
                    UIColor.black,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            }
        }
    }

    private func bindExtrinsic(viewModel: ExtrinsicTransactionDetailsViewModel) {
        amountView.isHidden = true
        slashView.isHidden = true
        rewardView.isHidden = true
        receiverView.isHidden = true
        eraView.isHidden = true
        senderView.isHidden = viewModel.sender == nil

        moduleView.valueLabel.text = viewModel.module
        callView.valueLabel.text = viewModel.call
        senderView.subtitleLabel?.text = viewModel.sender
        feeView.valueLabel.text = viewModel.fee

        if let sender = viewModel.sender {
            if let icon = try? UniversalIconGenerator().generateFromAddress(sender) {
                senderView.iconImage = icon.imageWithFillColor(
                    UIColor.black,
                    size: UIConstants.smallAddressIconSize,
                    contentScale: UIScreen.main.scale
                )
            }
        }
    }

    private func applyLocalization() {
        extrinsicHashView.titleLabel.text = R.string.localizable.transactionDetailsHashTitle(preferredLanguages: locale.rLanguages)
        senderView.titleLabel.text = R.string.localizable.transactionDetailsFrom(preferredLanguages: locale.rLanguages)
        receiverView.titleLabel.text = R.string.localizable.walletSendReceiverTitle(preferredLanguages: locale.rLanguages)
        statusView.titleLabel.text = R.string.localizable.transactionDetailStatus(preferredLanguages: locale.rLanguages)
        dateView.titleLabel.text = R.string.localizable.transactionDetailDate(preferredLanguages: locale.rLanguages)
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        moduleView.titleLabel.text = R.string.localizable.commonModule(preferredLanguages: locale.rLanguages)
        callView.titleLabel.text = R.string.localizable.commonCall(preferredLanguages: locale.rLanguages)
        eraView.titleLabel.text = R.string.localizable.stakingCommonEra(preferredLanguages: locale.rLanguages)
        slashView.titleLabel.text = R.string.localizable.stakingSlash(preferredLanguages: locale.rLanguages)
        rewardView.titleLabel.text = R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(navigationBar)
        navigationBar.setCenterViews([navigationTitleLabel])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(extrinsicHashView)
        contentView.stackView.addArrangedSubview(senderView)
        contentView.stackView.addArrangedSubview(receiverView)
        contentView.stackView.addArrangedSubview(statusView)
        contentView.stackView.addArrangedSubview(dateView)
        contentView.stackView.addArrangedSubview(amountView)
        contentView.stackView.addArrangedSubview(moduleView)
        contentView.stackView.addArrangedSubview(callView)
        contentView.stackView.addArrangedSubview(eraView)
        contentView.stackView.addArrangedSubview(slashView)
        contentView.stackView.addArrangedSubview(rewardView)
        contentView.stackView.addArrangedSubview(feeView)

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: extrinsicHashView)
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: senderView)
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: receiverView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: statusView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: dateView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: amountView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: moduleView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: callView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: eraView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: slashView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: rewardView)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: feeView)

        extrinsicHashView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        senderView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        receiverView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.triangularedViewHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        statusView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        dateView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        amountView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        moduleView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        callView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        feeView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        eraView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        slashView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        rewardView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.cellHeight)
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }
    }
}
