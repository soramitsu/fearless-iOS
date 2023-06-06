import UIKit
import SoraUI
import SoraFoundation

final class SelectValidatorsConfirmViewController: UIViewController, ViewHolder, ImportantViewProtocol {
    typealias RootViewType = SelectValidatorsConfirmViewLayout

    let presenter: SelectValidatorsConfirmPresenterProtocol
    let quantityFormatter: NumberFormatter

    private var confirmationViewModel: LocalizableResource<SelectValidatorsConfirmViewModel>?
    private var assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>?
    private var feeViewModel: LocalizableResource<BalanceViewModelProtocol>?
    private var hintsViewModel: LocalizableResource<[TitleIconViewModel]>?

    init(
        presenter: SelectValidatorsConfirmPresenterProtocol,
        quantityFormatter: NumberFormatter,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.presenter = presenter
        self.quantityFormatter = quantityFormatter

        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = SelectValidatorsConfirmViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
        updateActionButton()

        presenter.setup()
    }

    private func configure() {
        rootView.networkFeeFooterView.actionButton.addTarget(
            self,
            action: #selector(proceed),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonConfirmTitle(preferredLanguages: languages)

        rootView.mainAccountView.titleLabel.text = R.string.localizable.stakingStashTitle(
            preferredLanguages: languages
        )

        rootView.networkFeeFooterView.actionButton.imageWithTitleView?.title =
            R.string.localizable.commonConfirm(preferredLanguages: languages)
        rootView.networkFeeFooterView.actionButton.invalidateLayout()

        rootView.amountView.titleLabel.text = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        rootView.validatorsView.titleLabel.text = R.string.localizable.stakingSelectedValidatorsTitle(
            preferredLanguages: languages
        )

        rootView.rewardDestinationView.titleLabel.text = R.string.localizable.stakingRewardsDestinationTitle(
            preferredLanguages: languages
        )

        rootView.poolView.titleLabel.text = R.string.localizable.poolStakingSelectedPool(
            preferredLanguages: languages
        )

        rootView.networkFeeFooterView.locale = selectedLocale

        rootView.selectedCollatorTitle.text = R.string.localizable.stakingSelectedCollator(preferredLanguages: languages)

        applyConfirmationViewModel()
        applyHints()
        applyFeeViewModel()
    }

    private func updateActionButton() {
        let isEnabled = (assetViewModel != nil)
        rootView.networkFeeFooterView.actionButton.set(enabled: isEnabled)
    }

    private func applyConfirmationViewModel() {
        guard let viewModel = confirmationViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.amountView.isHidden = viewModel.amount == nil
        rootView.rewardDestinationView.isHidden = viewModel.rewardDestination == nil
        rootView.payoutAccountView?.isHidden = viewModel.rewardDestination == nil
        rootView.poolView.isHidden = viewModel.poolName == nil

        if let stakedViewModel = viewModel.stakeAmountViewModel?.value(for: selectedLocale) {
            rootView.stakeAmountView.bind(viewModel: stakedViewModel)
        }
        rootView.amountView.valueTop.text = viewModel.amount?.amount
        rootView.amountView.valueBottom.text = viewModel.amount?.price
        rootView.mainAccountView.valueTop.text = viewModel.senderName
        rootView.mainAccountView.valueBottom.text = viewModel.senderAddress

        switch viewModel.rewardDestination {
        case .restake:
            rootView.rewardDestinationView.valueTop.text = R.string.localizable
                .stakingRestakeTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.removePayoutAccountIfNeeded()
        case let .payout(_, title, address):
            rootView.rewardDestinationView.valueTop.text = R.string.localizable
                .stakingPayoutTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.addPayoutAccountIfNeeded()
            rootView.payoutAccountView?.titleLabel.text = R.string.localizable.stakingRewardPayoutAccount(
                preferredLanguages: selectedLocale.rLanguages
            )
            rootView.payoutAccountView?.valueTop.text = title
            rootView.payoutAccountView?.valueBottom.text = address
        case .none:
            rootView.rewardDestinationView.isHidden = true
            rootView.payoutAccountView?.isHidden = true
        }

        if let validatorsCount = viewModel.validatorsCount, let maxValidatorCount = viewModel.maxValidatorCount {
            rootView.validatorsView.valueLabel.text = R.string.localizable.stakingValidatorInfoNominators(
                quantityFormatter.string(from: NSNumber(value: validatorsCount)) ?? "",
                quantityFormatter.string(from: NSNumber(value: maxValidatorCount)) ?? ""
            )
        } else {
            rootView.validatorsView.isHidden = true
        }

        rootView.selectedCollatorView.isHidden = viewModel.selectedCollatorViewModel == nil
        rootView.selectedCollatorView.titleLabel.text = viewModel.selectedCollatorViewModel?.name
        rootView.selectedCollatorView.valueTop.text = viewModel.selectedCollatorViewModel?.address
        rootView.poolView.valueTop.text = viewModel.poolName
    }

    private func applyHints() {
        guard let hints = hintsViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.setHints(hints)
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeFooterView.bindBalance(viewModel: viewModel)
    }

    // MARK: Action

    @objc private func actionOnPayoutAccount() {
        presenter.selectPayoutAccount()
    }

    @objc private func actionOnWalletAccount() {
        presenter.selectWalletAccount()
    }

    @objc private func actionOnCollatorAccount() {
        presenter.selectCollatorAccount()
    }

    @objc private func proceed() {
        presenter.proceed()
    }
}

extension SelectValidatorsConfirmViewController: SelectValidatorsConfirmViewProtocol {
    func didReceive(confirmationViewModel: LocalizableResource<SelectValidatorsConfirmViewModel>) {
        self.confirmationViewModel = confirmationViewModel
        applyConfirmationViewModel()
    }

    func didReceive(hintsViewModel: LocalizableResource<[TitleIconViewModel]>) {
        self.hintsViewModel = hintsViewModel
        applyHints()
    }

    func didReceive(assetViewModel: LocalizableResource<AssetBalanceViewModelProtocol>) {
        self.assetViewModel = assetViewModel
        updateActionButton()
    }

    func didReceive(feeViewModel: LocalizableResource<BalanceViewModelProtocol>?) {
        self.feeViewModel = feeViewModel
        applyFeeViewModel()
    }
}

extension SelectValidatorsConfirmViewController {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
