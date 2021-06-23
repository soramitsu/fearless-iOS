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
    let applicationConfig: ApplicationConfigProtocol
    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var calculator: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var balance: Decimal?
    private var fee: Decimal?
    private var loadingFee: Bool = false
    private var asset: WalletAsset
    private var amount: Decimal?
    private var rewardDestination: RewardDestination<AccountItem> = .restake
    private var payoutAccount: AccountItem
    private var loadingPayouts: Bool = false
    private var minimalBalance: Decimal?
    private var minBondAmount: Decimal?
    private var counterForNominators: UInt32?
    private var maxNominatorsCount: UInt32?
    private var electionStatus: ElectionStatus?

    init(
        amount: Decimal?,
        asset: WalletAsset,
        selectedAccount: AccountItem,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        applicationConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        self.amount = amount
        self.asset = asset
        self.selectedAccount = selectedAccount
        payoutAccount = selectedAccount
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.applicationConfig = applicationConfig
        self.logger = logger
    }

    private func provideRewardDestination() {
        do {
            let reward: CalculatedReward?

            if let calculator = calculator {
                let restake = calculator.calculateMaxReturn(
                    isCompound: true,
                    period: .year
                )

                let payout = calculator.calculateMaxReturn(
                    isCompound: false,
                    period: .year
                )

                let curAmount = amount ?? 0.0
                reward = CalculatedReward(
                    restakeReturn: restake * curAmount,
                    restakeReturnPercentage: restake,
                    payoutReturn: payout * curAmount,
                    payoutReturnPercentage: payout
                )
            } else {
                reward = nil
            }

            switch rewardDestination {
            case .restake:
                let viewModel = rewardDestViewModelFactory.createRestake(from: reward, priceData: priceData)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            case .payout:
                let viewModel = try rewardDestViewModelFactory
                    .createPayout(from: reward, priceData: priceData, account: payoutAccount)
                view?.didReceiveRewardDestination(viewModel: viewModel)
            }
        } catch {
            logger.error("Can't create reward destination")
        }
    }

    private func provideAsset() {
        let viewModel = balanceViewModelFactory.createAssetBalanceViewModel(
            amount ?? 0.0,
            balance: balance,
            priceData: priceData
        )
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
        if !loadingFee, fee == nil {
            estimateFee()
        }
    }

    private func estimateFee() {
        if let amount = StakingConstants.maxAmount.toSubstrateAmount(precision: asset.precision) {
            loadingFee = true
            interactor.estimateFee(
                for: selectedAccount.address,
                amount: amount,
                rewardDestination: .payout(account: payoutAccount)
            )
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
                provideRewardDestination()
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
        if let view = view {
            wireframe.showWeb(
                url: applicationConfig.learnPayoutURL,
                from: view,
                style: .automatic
            )
        }
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue

        provideAsset()
        provideRewardDestination()
        scheduleFeeEstimation()
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        DataValidationRunner(validators: [
            dataValidatingFactory.has(fee: fee, locale: locale) { [weak self] in
                self?.scheduleFeeEstimation()
            },
            dataValidatingFactory.canPayFeeAndAmount(
                balance: balance,
                fee: fee,
                spendingAmount: amount,
                locale: locale
            ),
            dataValidatingFactory.canNominate(
                amount: amount,
                minimalBalance: minimalBalance,
                minNominatorBond: minBondAmount,
                locale: locale
            ),
            dataValidatingFactory.maxNominatorsCountNotReached(
                counterForNominators: counterForNominators,
                maxNominatorsCount: maxNominatorsCount,
                locale: locale
            ),
            dataValidatingFactory.electionClosed(electionStatus, locale: locale)
        ]).runValidation { [weak self] in
            guard
                let amount = self?.amount,
                let rewardDestination = self?.rewardDestination else {
                return
            }

            let stakingState = InitiatedBonding(
                amount: amount,
                rewardDestination: rewardDestination
            )

            self?.wireframe.proceed(from: self?.view, state: stakingState)
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
    func didReceive(accounts: [AccountItem]) {
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
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: asset.precision
            )
        } else {
            self.balance = 0.0
        }

        provideAsset()
    }

    func didReceive(
        paymentInfo: RuntimeDispatchInfo,
        for _: BigUInt,
        rewardDestination _: RewardDestination<AccountItem>
    ) {
        loadingFee = false

        if let feeValue = BigUInt(paymentInfo.fee),
           let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) {
            self.fee = fee
        } else {
            fee = nil
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

    func didReceive(minimalBalance: BigUInt) {
        if let amount = Decimal.fromSubstrateAmount(minimalBalance, precision: asset.precision) {
            logger.debug("Did receive minimun bonding amount: \(amount)")
            self.minimalBalance = amount
        }
    }

    func didReceive(minBondAmount: BigUInt?) {
        self.minBondAmount = minBondAmount.map { Decimal.fromSubstrateAmount($0, precision: asset.precision) } ?? nil
    }

    func didReceive(counterForNominators: UInt32?) {
        self.counterForNominators = counterForNominators
    }

    func didReceive(maxNominatorCount: UInt32?) {
        maxNominatorsCount = maxNominatorCount
    }

    func didReceive(electionStatus: ElectionStatus?) {
        self.electionStatus = electionStatus
    }
}

extension StakingAmountPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let accounts =
            (context as? PrimitiveContextWrapper<[AccountItem]>)?.value
        else {
            return
        }

        payoutAccount = accounts[index]

        if case .payout = rewardDestination {
            rewardDestination = .payout(account: payoutAccount)
        }

        provideRewardDestination()
    }
}
