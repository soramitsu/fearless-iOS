import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    private var balanceViewModelFactory: BalanceViewModelFactoryProtocol?
    private var rewardViewModelFactory: RewardViewModelFactoryProtocol?
    private var networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol?
    let viewModelFacade: StakingViewModelFacadeProtocol
    let logger: LoggerProtocol?

    private var stateViewModelFactory: StakingStateViewModelFactoryProtocol
    private var stateMachine: StakingStateMachineProtocol

    private var priceData: PriceData?
    private var balance: Decimal?
    private var amount: Decimal?
    private var calculator: RewardCalculatorEngineProtocol?

    private var chain: Chain?

    init(stateViewModelFactory: StakingStateViewModelFactoryProtocol,
         viewModelFacade: StakingViewModelFacadeProtocol,
         logger: LoggerProtocol?) {
        self.stateViewModelFactory = stateViewModelFactory
        self.viewModelFacade = viewModelFacade
        self.logger = logger

        let stateMachine = StakingStateMachine()
        self.stateMachine = stateMachine

        stateMachine.delegate = self
    }

    private func provideState() {
        let state = stateViewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: state)
    }

    private func provideChain() {
        guard let viewModelFactory = networkInfoViewModelFactory else {
            return
        }

        let chainModel = viewModelFactory.createChainViewModel()

        view?.didReceiveChainName(chainName: chainModel)
    }

    private func provideAsset() {
        guard let viewModelFactory = balanceViewModelFactory else {
            return
        }

        let viewModel = viewModelFactory.createAssetBalanceViewModel(amount ?? 0.0,
                                                                     balance: balance,
                                                                     priceData: priceData)
        view?.didReceiveAsset(viewModel: viewModel)
    }

    private func provideReward() {
        guard let viewModelFactory = rewardViewModelFactory else {
            return
        }

        do {

            let monthlyReturn: Decimal
            let yearlyReturn: Decimal

            if let calculator = calculator {
                monthlyReturn = try calculator.calculateNetworkReturn(isCompound: true,
                                                                      period: .month)
                yearlyReturn = try calculator.calculateNetworkReturn(isCompound: true,
                                                                     period: .year)
            } else {
                monthlyReturn = 0.0
                yearlyReturn = 0.0
            }

            let monthlyViewModel = viewModelFactory
                .createRewardViewModel(reward: (amount ?? 0.0) * monthlyReturn,
                                       targetReturn: monthlyReturn,
                                       priceData: priceData)

            let yearlyViewModel = viewModelFactory
                .createRewardViewModel(reward: (amount ?? 0.0) * yearlyReturn,
                                       targetReturn: yearlyReturn,
                                       priceData: priceData)

            view?.didReceiveRewards(monthlyViewModel: monthlyViewModel,
                                    yearlyViewModel: yearlyViewModel)

        } catch {
            logger?.error("Can't calculate reward")
        }
    }

    private func provideAmountInputViewModel() {
        guard let viewModelFactory = balanceViewModelFactory else {
            return
        }

        let viewModel = viewModelFactory.createBalanceInputViewModel(amount)
        view?.didReceiveInput(viewModel: viewModel)
    }
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        provideState()
        interactor.setup()
    }

    func performMainAction() {
        wireframe.showSetupAmount(from: view, amount: amount)
    }

    func performAccountAction() {
        logger?.debug("Did select account")
    }

    func updateAmount(_ newValue: Decimal) {
        amount = newValue
        provideAsset()
        provideReward()
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance {
            let newAmount = balance * Decimal(Double(percentage))

            if newAmount >= 0 {
                amount = newAmount

                provideAmountInputViewModel()
                provideAsset()
                provideReward()
            } else if let view = view {
                wireframe.presentAmountTooHigh(from: view,
                                               locale: view.localizationManager?.selectedLocale)
            }
        }
    }
}

extension StakingMainPresenter: StakingStateMachineDelegate {
    func stateMachineDidChangeState(_ stateMachine: StakingStateMachineProtocol) {
        provideState()
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            logger?.error("Did receive error: \(error)")
        }
    }

    func didReceive(price: PriceData?) {
        stateMachine.state.process(price: price)

        self.priceData = price
        provideAsset()
        provideReward()
    }

    func didReceive(priceError: Error) {
        handle(error: priceError)
    }

    func didReceive(accountInfo: DyAccountInfo?) {
        stateMachine.state.process(accountInfo: accountInfo)

        if let availableValue = accountInfo?.data.available, let chain = chain {
            self.balance = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: chain.addressType.precision)
        } else {
            self.balance = 0.0
        }

        provideAsset()
    }

    func didReceive(balanceError: Error) {
        handle(error: balanceError)
    }

    func didReceive(selectedAddress: String) {
        stateMachine.state.process(address: selectedAddress)

        let viewModel = StakingMainViewModel(address: selectedAddress)
        view?.didReceive(viewModel: viewModel)
    }

    func didReceive(calculator: RewardCalculatorEngineProtocol) {
        stateMachine.state.process(calculator: calculator)

        self.calculator = calculator
        provideReward()
    }

    func didReceive(calculatorError: Error) {
        handle(error: calculatorError)
    }

    func didReceive(stashItem: StashItem?) {
        stateMachine.state.process(stashItem: stashItem)

        if let stashItem = stashItem {
            logger?.debug("Stash: \(stashItem.stash)")
            logger?.debug("Controller: \(stashItem.controller)")
        } else {
            logger?.debug("No stash found")
        }
    }

    func didReceive(stashItemError: Error) {
        handle(error: stashItemError)
    }

    func didReceive(ledgerInfo: DyStakingLedger?) {
        stateMachine.state.process(ledgerInfo: ledgerInfo)

        if let ledgerInfo = ledgerInfo {
            logger?.debug("Did receive ledger info: \(ledgerInfo)")
        } else {
            logger?.debug("No ledger info received")
        }
    }

    func didReceive(ledgerInfoError: Error) {
        handle(error: ledgerInfoError)
    }

    func didReceive(nomination: Nomination?) {
        stateMachine.state.process(nomination: nomination)

        if let nomination = nomination {
            logger?.debug("Did receive nomination: \(nomination)")
        } else {
            logger?.debug("No nomination received")
        }
    }

    func didReceive(nominationError: Error) {
        handle(error: nominationError)
    }

    func didReceive(validatorPrefs: ValidatorPrefs?) {
        stateMachine.state.process(validatorPrefs: validatorPrefs)

        if let prefs = validatorPrefs {
            logger?.debug("Did receive validator: \(prefs)")
        } else {
            logger?.debug("No validator received")
        }
    }

    func didReceive(validatorError: Error) {
        handle(error: validatorError)
    }

    func didReceive(electionStatus: ElectionStatus?) {
        stateMachine.state.process(electionStatus: electionStatus)

        switch electionStatus {
        case .close:
            logger?.debug("Election status: close")
        case .open(let blockNumber):
            logger?.debug("Election status: open from \(blockNumber)")
        case .none:
            logger?.debug("No election status set")
        }
    }

    func didReceive(electionStatusError: Error) {
        handle(error: electionStatusError)
    }

    func didReceive(eraStakersInfo: EraStakersInfo) {
        stateMachine.state.process(eraStakersInfo: eraStakersInfo)

        logger?.debug("Did receive era stakers info: \(eraStakersInfo.era)")
    }

    func didReceive(eraStakersInfoError: Error) {
        handle(error: eraStakersInfoError)
    }

    func didReceive(newChain: Chain) {
        stateMachine.state.process(chain: newChain)

        self.chain = newChain
        self.balanceViewModelFactory = viewModelFacade.createBalanceViewModelFactory(for: newChain)
        self.rewardViewModelFactory = viewModelFacade.createRewardViewModelFactory(for: newChain)
        self.networkInfoViewModelFactory = viewModelFacade.createNetworkInfoViewModelFactory(for: newChain)

        self.amount = nil
        self.calculator = nil
        self.priceData = nil

        provideReward()
        provideAsset()
        provideAmountInputViewModel()
        provideChain()
    }
}
