import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let viewModelFacade: StakingViewModelFacadeProtocol
    let logger: LoggerProtocol?

    private var networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol?
    private var stateViewModelFactory: StakingStateViewModelFactoryProtocol
    private var stateMachine: StakingStateMachineProtocol

    private var balance: Decimal?
    private var amount: Decimal?
    private var eraStakersInfo: EraStakersInfo?
    private var priceData: PriceData?
    private var lockUpPeriodInEras: UInt32?

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

    private func provideLockUpPeriod() {
        guard let factory = networkInfoViewModelFactory else { return }

        let lockUpPeriodViewModel = factory.createEraLockUpPeriodViewModel(with: lockUpPeriodInEras ?? 0)

        view?.didReceiveLockupPeriod(lockUpPeriodViewModel)
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

    private func provideEraStakersInfo() {
        guard let viewModelFactory = self.networkInfoViewModelFactory,
              let eraStakersInfo = self.eraStakersInfo else {
            return
        }

        let eraStakingInfoViewModel = viewModelFactory.createEraStakingInfoViewModel(with: eraStakersInfo)
        view?.didReceiveEraStakingInfo(viewModel: eraStakingInfoViewModel)
    }
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        provideState()
        provideChain()
        provideEraStakersInfo()
        provideLockUpPeriod()
        
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
        stateMachine.state.process(rewardEstimationAmount: newValue)
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance {
            amount = balance * Decimal(Double(percentage))
            stateMachine.state.process(rewardEstimationAmount: amount)
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

        guard let newPriceData = price else { return }

        networkInfoViewModelFactory?.updatePriceData(with: newPriceData)
        provideEraStakersInfo()
    }

    func didReceive(priceError: Error) {
        handle(error: priceError)
    }

    func didReceive(totalReward: TotalRewardItem) {
        stateMachine.state.process(totalReward: totalReward)
    }

    func didReceive(totalReward: Error) {
        handle(error: totalReward)
    }

    func didReceive(accountInfo: DyAccountInfo?) {
        if let availableValue = accountInfo?.data.available, let chain = chain {
            self.balance = Decimal.fromSubstrateAmount(availableValue,
                                                       precision: chain.addressType.precision)
        } else {
            self.balance = 0.0
        }

        stateMachine.state.process(accountInfo: accountInfo)
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

        self.eraStakersInfo = eraStakersInfo
        provideEraStakersInfo()

        logger?.debug("Did receive era stakers info: \(eraStakersInfo.era)")
    }

    func didReceive(eraStakersInfoError: Error) {
        handle(error: eraStakersInfoError)
    }

    func didReceive(newChain: Chain) {
        chain = newChain

        if let factory = networkInfoViewModelFactory {
            factory.updateChain(with: newChain)
        } else {
            networkInfoViewModelFactory = viewModelFacade.createNetworkInfoViewModelFactory(for: newChain)
        }

        self.amount = nil

        stateMachine.state.process(chain: newChain)

        provideChain()
    }

    func didRecieve(lockUpPeriod: UInt32) {
        lockUpPeriodInEras = lockUpPeriod
        provideLockUpPeriod()
    }

    func didRecieve(lockUpPeriodError: Error) {
        handle(error: lockUpPeriodError)
    }
}
