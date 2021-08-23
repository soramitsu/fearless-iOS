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
        rootView.mainAccountView.addTarget(
            self,
            action: #selector(actionOnWalletAccount),
            for: .touchUpInside
        )

        rootView.networkFeeConfirmView.actionButton.addTarget(
            self,
            action: #selector(proceed),
            for: .touchUpInside
        )
    }

    private func setupLocalization() {
        let languages = selectedLocale.rLanguages

        title = R.string.localizable.commonConfirmTitle(preferredLanguages: languages)

        rootView.mainAccountView.title = R.string.localizable.stakingStashTitle(
            preferredLanguages: languages
        )

        rootView.networkFeeConfirmView.actionButton.imageWithTitleView?.title =
            R.string.localizable.commonConfirm(preferredLanguages: languages)
        rootView.networkFeeConfirmView.actionButton.invalidateLayout()

        rootView.amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: languages)

        rootView.validatorsView.titleLabel.text = R.string.localizable.stakingSelectedValidatorsTitle(
            preferredLanguages: languages
        )

        rootView.rewardDestinationView.titleLabel.text = R.string.localizable.stakingRewardsDestinationTitle(
            preferredLanguages: languages
        )

        rootView.networkFeeConfirmView.locale = selectedLocale

        applyConfirmationViewModel()
        applyHints()
        applyBalanceView()
        applyFeeViewModel()
    }

    private func updateActionButton() {
        let isEnabled = (assetViewModel != nil)
        rootView.networkFeeConfirmView.actionButton.set(enabled: isEnabled)
    }

    private func applyConfirmationViewModel() {
        guard let viewModel = confirmationViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.amountView.fieldText = viewModel.amount

        rootView.mainAccountView.iconImage = viewModel.senderIcon
            .imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

        rootView.mainAccountView.subtitle = viewModel.senderName

        switch viewModel.rewardDestination {
        case .restake:
            rootView.rewardDestinationView.valueLabel.text = R.string.localizable
                .stakingRestakeTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.removePayoutAccountIfNeeded()
        case let .payout(icon, title):
            rootView.rewardDestinationView.valueLabel.text = R.string.localizable
                .stakingPayoutTitle(preferredLanguages: selectedLocale.rLanguages)
            rootView.addPayoutAccountIfNeeded()

            rootView.payoutAccountView?.addTarget(
                self,
                action: #selector(actionOnPayoutAccount),
                for: .touchUpInside
            )

            rootView.payoutAccountView?.title = R.string.localizable.stakingRewardPayoutAccount(
                preferredLanguages: selectedLocale.rLanguages
            )

            rootView.payoutAccountView?.iconImage = icon.imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )
            rootView.payoutAccountView?.subtitle = title
        }

        rootView.validatorsView.valueLabel.text = R.string.localizable.stakingValidatorInfoNominators(
            quantityFormatter.string(from: NSNumber(value: viewModel.validatorsCount)) ?? "",
            quantityFormatter.string(from: NSNumber(value: viewModel.maxValidatorCount)) ?? ""
        )
    }

    private func applyHints() {
        guard let hints = hintsViewModel?.value(for: selectedLocale) else {
            return
        }

        rootView.setHints(hints)
    }

    private func applyBalanceView() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        guard let viewModel = assetViewModel?.value(for: locale) else {
            return
        }

        rootView.amountView.balanceText = R.string.localizable
            .commonAvailableFormat(
                viewModel.balance ?? "",
                preferredLanguages: locale.rLanguages
            )
        rootView.amountView.priceText = viewModel.price

        rootView.amountView.assetIcon = viewModel.icon
        rootView.amountView.symbol = viewModel.symbol
    }

    private func applyFeeViewModel() {
        let viewModel = feeViewModel?.value(for: selectedLocale)
        rootView.networkFeeConfirmView.networkFeeView.bind(viewModel: viewModel)
    }

    // MARK: Action

    @objc private func actionOnPayoutAccount() {
        presenter.selectPayoutAccount()
    }

    @objc private func actionOnWalletAccount() {
        presenter.selectWalletAccount()
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
        applyBalanceView()
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
            applyLocalization()
            view.setNeedsLayout()
        }
    }
}
