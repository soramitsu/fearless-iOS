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

    private var calculator: RewardCalculatorEngineProtocol?
    private var priceData: PriceData?
    private var balance: Decimal?
    private var loadingFee: Bool = false
    private var asset: AssetModel
    private var chain: ChainModel
    private var rewardDestination: RewardDestination<ChainAccountResponse> = .restake
    private var payoutAccount: ChainAccountResponse?
    private var loadingPayouts: Bool = false
    private var minimalBalance: Decimal?
    private var minBondAmount: Decimal?
    private var minStake: Decimal?

    private var counterForNominators: UInt32?
    private var maxNominatorsCount: UInt32?
    private var networkStakingInfo: NetworkStakingInfo?

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
        payoutAccount = selectedAccount.fetch(for: chain.accountRequest())
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
        self.balanceViewModelFactory = balanceViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.applicationConfig = applicationConfig
        self.logger = logger
        self.viewModelState = viewModelState
        self.viewModelFactory = viewModelFactory
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

                let curAmount = viewModelState?.amount ?? 0.0
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
                if let payoutAccount = payoutAccount,
                   let address = payoutAccount.toAddress() {
                    let viewModel = try rewardDestViewModelFactory
                        .createPayout(from: reward, priceData: priceData, address: address, title: (try? payoutAccount.toDisplayAddress().username) ?? address)
                    view?.didReceiveRewardDestination(viewModel: viewModel)
                }
            }
        } catch {
            logger.error("Can't create reward destination")
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
            let feeViewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
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
        if !loadingFee, viewModelState?.fee == nil {
            estimateFee()
        }
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
//        rewardDestination = .restake
//        provideRewardDestination()
//
//        scheduleFeeEstimation()
    }

    func selectPayoutDestination() {
        viewModelState?.selectPayoutDestination()

//        guard let payoutAccount = payoutAccount else {
//            return
//        }
//
//        rewardDestination = .payout(account: payoutAccount)
//        provideRewardDestination()
//
//        scheduleFeeEstimation()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance, let fee = viewModelState?.fee {
            let newAmount = max(balance - fee, 0.0) * Decimal(Double(percentage))

            if newAmount > 0 {
                viewModelState?.updateAmount(newAmount)

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
        viewModelState?.updateAmount(newValue)

        provideAsset()
        provideRewardDestination()
        scheduleFeeEstimation()
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let customValidators: [DataValidating] = viewModelState?.validators ?? []
        let commonValidators: [DataValidating] = [
            //            dataValidatingFactory.has(fee: viewModelState?.fee, locale: locale) { [weak self] in
//                self?.scheduleFeeEstimation()
//            },
//            dataValidatingFactory.canPayFeeAndAmount(
//                balance: balance,
//                fee: viewModelState?.fee,
//                spendingAmount: viewModelState?.amount,
//                locale: locale
//            ),
//            dataValidatingFactory.canNominate(
//                amount: viewModelState?.amount,
//                minimalBalance: minimalBalance,
//                minNominatorBond: minBondAmount,
//                locale: locale
//            ),
//            dataValidatingFactory.bondAtLeastMinStaking(
//                asset: asset,
//                amount: viewModelState?.amount,
//                minNominatorBond: minStake,
//                locale: locale
//            ),
//            dataValidatingFactory.maxNominatorsCountNotApplied(
//                counterForNominators: counterForNominators,
//                maxNominatorsCount: maxNominatorsCount,
//                hasExistingNomination: false,
//                locale: locale
//            )
        ]

        DataValidationRunner(validators: customValidators + commonValidators).runValidation { [weak self] in
            guard
                let strongSelf = self,
                let amount = strongSelf.viewModelState?.amount
            else {
                return
            }

            let stakingState = InitiatedBonding(
                amount: amount,
                rewardDestination: strongSelf.rewardDestination
            )

            strongSelf.wireframe.proceed(
                from: strongSelf.view,
                state: stakingState,
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
        guard let payoutAccount = payoutAccount else {
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
//        provideFee()
        provideRewardDestination()
    }

    func didReceive(balance: AccountData?) {
        if let availableValue = balance?.available {
            self.balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(asset.precision)
            )
        } else {
            self.balance = 0.0
        }

        provideAsset()
    }

    func didReceive(paymentInfo _: RuntimeDispatchInfo) {
//        loadingFee = false
//
//        if let feeValue = BigUInt(paymentInfo.fee),
//           let fee = Decimal.fromSubstrateAmount(feeValue, precision: Int16(asset.precision)) {
//            self.fee = fee
//        } else {
//            fee = nil
//        }

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

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo

        let minStakeSubstrateAmount = networkStakingInfo.calculateMinimumStake(given: minBondAmount?.toSubstrateAmount(precision: Int16(asset.precision)))
        minStake = Decimal.fromSubstrateAmount(minStakeSubstrateAmount, precision: Int16(asset.precision))
    }

    func didReceive(networkStakingInfoError _: Error) {}

    func didReceive(minimalBalance: BigUInt) {
        if let amount = Decimal.fromSubstrateAmount(minimalBalance, precision: Int16(asset.precision)) {
            logger.debug("Did receive minimun bonding amount: \(amount)")
            self.minimalBalance = amount
        }
    }

    func didReceive(minBondAmount: BigUInt?) {
        self.minBondAmount = minBondAmount.map { Decimal.fromSubstrateAmount($0, precision: Int16(asset.precision)) } ?? nil
    }

    func didReceive(counterForNominators: UInt32?) {
        self.counterForNominators = counterForNominators
    }

    func didReceive(maxNominatorsCount: UInt32?) {
        self.maxNominatorsCount = maxNominatorsCount
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

        payoutAccount = accounts[index]

        if let payoutAccount = payoutAccount, case .payout = rewardDestination {
            rewardDestination = .payout(account: payoutAccount)
        }

        provideRewardDestination()
    }
}

extension StakingAmountPresenter: StakingAmountModelStateListener {
    func modelStateDidChanged(viewModelState: StakingAmountViewModelState) {
        if let viewModel = viewModelFactory?.buildViewModel(viewModelState: viewModelState, priceData: priceData, calculator: calculator) {
            view?.didReceive(viewModel: viewModel)
        }
    }
}
