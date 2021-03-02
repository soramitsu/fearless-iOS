import Foundation
import CommonWallet
import BigInt

final class StakingAmountPresenter {
    weak var view: StakingAmountViewProtocol?
    var wireframe: StakingAmountWireframeProtocol!
    var interactor: StakingAmountInteractorInputProtocol!

    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    let selectedAccount: AccountItem
    let logger: LoggerProtocol
    let feeDebounce: TimeInterval
    let applicationConfig: ApplicationConfigProtocol

    private var calculator: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?
    private var loadingFee: Bool = false
    private var asset: WalletAsset
    private var amount: Decimal?
    private var rewardDestination: RewardDestination = .restake
    private var payoutAccount: AccountItem
    private var loadingPayouts: Bool = false

    private lazy var scheduler: SchedulerProtocol = Scheduler(with: self, callbackQueue: .main)

    deinit {
        scheduler.cancel()
    }

    init(asset: WalletAsset,
         selectedAccount: AccountItem,
         rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
         balanceViewModelFactory: BalanceViewModelFactoryProtocol,
         feeDebounce: TimeInterval = 2.0,
         applicationConfig: ApplicationConfigProtocol,
         logger: LoggerProtocol) {
        self.asset = asset
        self.selectedAccount = selectedAccount
        self.payoutAccount = selectedAccount
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.feeDebounce = feeDebounce
        self.applicationConfig = applicationConfig
        self.logger = logger
    }

    private func provideRewardDestination() {
        do {
            let reward: CalculatedReward?

            if let calculator = calculator {
                let restake =  try calculator.calculateNetworkReturn(isCompound: true,
                                                                     period: .year)

                let payout = try calculator.calculateNetworkReturn(isCompound: false,
                                                                   period: .year)

                let curAmount = amount ?? 0.0
                reward = CalculatedReward(restakeReturn: restake * curAmount,
                                          restakeReturnPercentage: restake,
                                          payoutReturn: payout * curAmount,
                                          payoutReturnPercentage: payout)
            } else {
                reward = nil
            }

            switch rewardDestination {
            case .restake:
                let viewModel = rewardDestViewModelFactory.createRestake(from: reward)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            case .payout:
                let viewModel = try rewardDestViewModelFactory
                    .createPayout(from: reward, account: payoutAccount)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            }
        } catch {
            logger.error("Can't create reward destination")
        }
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(amount ?? 0.0,
                                                                            balance: balance,
                                                                            priceData: priceData)
        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideFee() {
        if let fee = fee {
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceiveFee(viewModel: feeViewModel)
        } else {
            view?.didReceiveFee(viewModel: nil)
        }
    }

    private func provideAmountInputViewModel() {
        let viewModel = balanceViewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }

    private func scheduleFeeEstimation() {
        scheduler.cancel()

        if !loadingFee {
            loadingFee = true
            estimateFee()
        } else {
            scheduler.notifyAfter(feeDebounce)
        }
    }

    private func estimateFee() {
        if let amount = (amount ?? 0.0).toSubstrateAmount(precision: asset.precision) {
            loadingFee = true
            interactor.estimateFee(for: selectedAccount.address,
                                   amount: amount,
                                   rewardDestination: rewardDestination)
        }
    }
}

extension StakingAmountPresenter: StakingAmountPresenterProtocol {
    func setup() {
        provideAmountInputViewModel()
        provideRewardDestination()

        interactor.setup()

        estimateFee()
    }

    func selectRestakeDestination() {
        rewardDestination = .restake
        provideRewardDestination()

        scheduleFeeEstimation()
    }

    func selectPayoutDestination() {
        rewardDestination = .payout(account: payoutAccount)
        provideRewardDestination()

        scheduleFeeEstimation()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance, let fee = fee {
            let newAmount = max(balance - fee, 0.0) * Decimal(Double(percentage))

            if newAmount > 0 {
                amount = newAmount

                provideAmountInputViewModel()
                provideAsset()
            } else if let view = view {
                wireframe.presentBalanceTooHigh(from: view,
                                                locale: view.localizationManager?.selectedLocale)
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
        if let view = view {
            wireframe.showWeb(url: applicationConfig.learnPayoutURL,
                              from: view,
                              style: .automatic)
        }
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAsset()
        provideRewardDestination()
        scheduleFeeEstimation()
    }

    func proceed() {
        guard let amount = amount, let balance = balance else {
            return
        }

        guard let fee = fee else {
            if let view = view {
                wireframe.presentFeeNotReceived(from: view,
                                                locale: view.localizationManager?.selectedLocale)
            }

            return
        }

        guard amount + fee <= balance else {
            if let view = view {
                wireframe.presentBalanceTooHigh(from: view,
                                                locale: view.localizationManager?.selectedLocale)
            }

            return
        }

        let stakingState = StartStakingResult(amount: amount,
                                              rewardDestination: rewardDestination)

        wireframe.proceed(from: view, result: stakingState)
    }

    func close() {
        wireframe.close(view: view)
    }
}

extension StakingAmountPresenter: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        estimateFee()
    }
}

extension StakingAmountPresenter: StakingAmountInteractorOutputProtocol {
    func didReceive(accounts: [AccountItem]) {
        loadingPayouts = false

        let context = PrimitiveContextWrapper(value: accounts)

        wireframe.presentAccountSelection(accounts,
                                          selectedAccountItem: payoutAccount,
                                          delegate: self,
                                          from: view,
                                          context: context)
    }

    func didReceive(price: PriceData?) {
        self.priceData = price
        provideAsset()
        provideFee()
    }

    func didReceive(balance: DyAccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: asset.precision)
        } else {
            self.balance = 0.0
        }

        provideAsset()
    }

    func didReceive(paymentInfo: RuntimeDispatchInfo,
                    for amount: BigUInt,
                    rewardDestination: RewardDestination) {
        loadingFee = false

        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) {
            self.fee = fee
        } else {
            self.fee = nil
        }

        provideFee()
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
            (context as? PrimitiveContextWrapper<[AccountItem]>)?.value else {
            return
        }

        payoutAccount = accounts[index]

        if case .payout = rewardDestination {
            rewardDestination = .payout(account: payoutAccount)
        }

        provideRewardDestination()
    }
}
