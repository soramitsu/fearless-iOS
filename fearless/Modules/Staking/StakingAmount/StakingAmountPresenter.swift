import Foundation
import CommonWallet
import BigInt

final class StakingAmountPresenter {
    weak var view: StakingAmountViewProtocol?
    var wireframe: StakingAmountWireframeProtocol!
    var interactor: StakingAmountInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let selectedAccount: MetaAccountModel
    let logger: LoggerProtocol
    let applicationConfig: ApplicationConfigProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    let viewModelState: StakingAmountViewModelState?
    let viewModelFactory: StakingAmountViewModelFactoryProtocol?
    private var balance: Decimal?
    private var calculator: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var loadingFee: Bool = false
    private var asset: AssetModel
    private var chain: ChainModel
    private var loadingPayouts: Bool = false

    init(
        amount _: Decimal?,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol,
        viewModelState: StakingAmountViewModelState?,
        viewModelFactory: StakingAmountViewModelFactoryProtocol?
    ) {
        self.asset = asset
        self.chain = chain
        self.selectedAccount = selectedAccount
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.applicationConfig = applicationConfig
        self.logger = logger
        self.viewModelState = viewModelState
        self.viewModelFactory = viewModelFactory
    }

    private func provideRewardDestination() {
        guard let viewModelState = viewModelState else {
            return
        }

        if let viewModel = try? viewModelFactory?.buildSelectRewardDestinationViewModel(
            viewModelState: viewModelState,
            priceData: priceData,
            calculator: calculator
        ) {
            view?.didReceiveRewardDestination(viewModel: viewModel)
        }

        if let viewModel = viewModelFactory?.buildYourRewardDestinationViewModel(
            viewModelState: viewModelState,
            priceData: priceData,
            calculator: calculator
        ) {
            view?.didReceiveYourRewardDestination(viewModel: viewModel)
        }
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState?.amount ?? 0.0,
            balance: balance,
            priceData: priceData
        )
        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideFee() {
        if let fee = viewModelState?.fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData, usageCase: .detailsCrypto)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(viewModelState?.amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func scheduleFeeEstimation() {
        estimateFee()
    }

    private func estimateFee() {
        if let extrinsicBuilderClosure = viewModelState?.feeExtrinsicBuilderClosure {
            loadingFee = true
            interactor.estimateFee(extrinsicBuilderClosure: extrinsicBuilderClosure)
        }
    }
}

extension StakingAmountPresenter: StakingAmountPresenterProtocol {
    func setup() {
        viewModelState?.setStateListener(self)

        provideAmountInputViewModel()
        provideRewardDestination()

        interactor.setup()

        estimateFee()
    }

    func selectRestakeDestination() {
        viewModelState?.selectRestakeDestination()
        scheduleFeeEstimation()
    }

    func selectPayoutDestination() {
        viewModelState?.selectPayoutDestination()
        scheduleFeeEstimation()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance, let fee = viewModelState?.fee {
            let newAmount = max(balance - fee, 0.0) * Decimal(Double(percentage))

            if newAmount > 0 {
                viewModelState?.selectAmountPercentage(percentage)

                provideAmountInputViewModel()
                provideAsset()
                provideRewardDestination()

                scheduleFeeEstimation()

            } else if let view = view {
                wireframe.presentAmountTooHigh(
                    from: view,
                    locale: view.localizationManager?.selectedLocale
                )
            }
        }
    }

    func selectPayoutAccount() {
        guard !loadingPayouts else {
            return
        }

        loadingPayouts = true

        interactor.fetchAccounts()
    }

    func selectLearnMore() {
        guard let learnMoreUrl = viewModelState?.learnMoreUrl else {
            return
        }

        if let view = view {
            wireframe.showWeb(
                url: learnMoreUrl,
                from: view,
                style: .automatic
            )
        }
    }

    func updateAmount(_ newValue: Decimal) {
        viewModelState?.updateAmount(newValue)

        provideAsset()
        provideRewardDestination()
        scheduleFeeEstimation()
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let customValidators: [DataValidating] = viewModelState?.validators(using: locale) ?? []
        let commonValidators: [DataValidating] = [
            dataValidatingFactory.has(fee: viewModelState?.fee, locale: locale) { [weak self] in
                self?.scheduleFeeEstimation()
            },
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: viewModelState?.fee,
                spendingAmount: viewModelState?.amount,
                locale: locale
            )
        ]

        DataValidationRunner(validators: customValidators + commonValidators).runValidation { [weak self] in
            guard
                let strongSelf = self,
                let bonding = strongSelf.viewModelState?.bonding
            else {
                return
            }

            strongSelf.wireframe.proceed(
                from: strongSelf.view,
                state: bonding,
                asset: strongSelf.asset,
                chain: strongSelf.chain,
                selectedAccount: strongSelf.selectedAccount
            )
        }
    }

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingAmountPresenter: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        estimateFee()
    }
}

extension StakingAmountPresenter: StakingAmountInteractorOutputProtocol {
    func didReceive(accounts: [ChainAccountResponse]) {
        guard let payoutAccount = viewModelState?.payoutAccount else {
            return
        }

        loadingPayouts = false

        let context = PrimitiveContextWrapper(value: accounts)

        wireframe.presentAccountSelection(
            accounts,
            selectedAccountItem: payoutAccount,
            delegate: self,
            from: view,
            context: context
        )
    }

    func didReceive(price: PriceData?) {
        priceData = price
        provideAsset()
        provideFee()
        provideRewardDestination()
    }

    func didReceive(balance: AccountData?) {
        if let availableValue = balance?.stakingAvailable {
            self.balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(asset.precision)
            )

            viewModelState?.updateBalance(self.balance)
        } else {
            self.balance = 0.0

            viewModelState?.updateBalance(0.0)
        }

        provideAsset()
    }

    func didReceive(error: Error) {
        loadingPayouts = false
        loadingFee = false

        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger.error("Did receive error: \(error)")
        }
    }

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        self.calculator = calculator
        provideRewardDestination()
    }

    func didReceive(calculatorError: Error) {
        let locale = view?.localizationManager?.selectedLocale
        if !wireframe.present(error: calculatorError, from: view, locale: locale) {
            logger.error("Did receive error: \(calculatorError)")
        }
    }
}

extension StakingAmountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let accounts =
            (context as? PrimitiveContextWrapper<[ChainAccountResponse]>)?.value
        else {
            return
        }

        viewModelState?.selectPayoutAccount(payoutAccount: accounts[index])
    }
}

extension StakingAmountPresenter: StakingAmountModelStateListener {
    func modelStateDidChanged(viewModelState: StakingAmountViewModelState) {
        if let viewModel = viewModelFactory?.buildViewModel(viewModelState: viewModelState, priceData: priceData, calculator: calculator) {
            view?.didReceive(viewModel: viewModel)
        }
    }

    func provideYourRewardDestinationViewModel(viewModelState: StakingAmountViewModelState) {
        guard let viewModel = viewModelFactory?.buildYourRewardDestinationViewModel(viewModelState: viewModelState, priceData: priceData, calculator: calculator) else {
            return
        }

        view?.didReceiveYourRewardDestination(viewModel: viewModel)
    }
}
