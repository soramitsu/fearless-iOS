import Foundation
import CommonWallet
import BigInt

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!

    let networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol
    let viewModelFacade: StakingViewModelFacadeProtocol
    let logger: LoggerProtocol?

    private var stateViewModelFactory: StakingStateViewModelFactoryProtocol
    private var stateMachine: StakingStateMachineProtocol

    var chain: Chain? {
        stateMachine.viewState { (state: BaseStakingState) in state.commonData.chain }
    }

    var amount: Decimal? {
        if let amount = stateMachine
            .viewState(using: { (state: NoStashState) in state.rewardEstimationAmount }) {
            return amount
        }

        return stateMachine.viewState { (state: BondedState) in state.rewardEstimationAmount }
    }

    var priceData: PriceData? {
        stateMachine.viewState { (state: BaseStakingState) in state.commonData.price }
    }

    private var balance: Decimal?
    private var networkStakingInfo: NetworkStakingInfo?

    init(stateViewModelFactory: StakingStateViewModelFactoryProtocol,
         networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
         viewModelFacade: StakingViewModelFacadeProtocol,
         logger: LoggerProtocol?) {
        self.stateViewModelFactory = stateViewModelFactory
        self.networkInfoViewModelFactory = networkInfoViewModelFactory
        self.viewModelFacade = viewModelFacade
        self.logger = logger

        let stateMachine = StakingStateMachine()
        self.stateMachine = stateMachine

        stateMachine.delegate = self
    }

    private func provideStakingInfo() {
        let commonData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }

        guard let chain = commonData?.chain else {
            return
        }

        let networkStakingInfoViewModel = networkInfoViewModelFactory
            .createNetworkStakingInfoViewModel(with: networkStakingInfo,
                                               chain: chain,
                                               priceData: commonData?.price)
        view?.didRecieveNetworkStakingInfo(viewModel: networkStakingInfoViewModel)
    }

    private func provideState() {
        let state = stateViewModelFactory.createViewModel(from: stateMachine.state)
        view?.didReceiveStakingState(viewModel: state)
    }

    private func provideChain() {
        let commonData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }

        guard let chain = commonData?.chain else {
            return
        }

        let chainModel = networkInfoViewModelFactory.createChainViewModel(for: chain)

        view?.didReceiveChainName(chainName: chainModel)
    }
}

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func setup() {
        provideState()
        provideChain()
        provideStakingInfo()

        interactor.setup()
    }

    func performMainAction() {
        let bonded = stateMachine.viewState { (_ : BondedState) in true } ?? false

        if bonded {
            if let stashItem = stateMachine.viewState(using: { (state: BondedState) in state.stashItem }) {
                interactor.fetchController(for: stashItem.controller)
            } else {
                logger?.warning("Unexpected state on main action")
            }
        } else {
            wireframe.showSetupAmount(from: view, amount: amount)
        }
    }

    func performNominationStatusAction() {
        let optViewModel: AlertPresentableViewModel? = stateMachine.viewState { (state: NominatorState) in
            let locale = view?.localizationManager?.selectedLocale
            return state.createStatusPresentableViewModel(for: networkStakingInfo?.minimalStake,
                                                          locale: locale)
        }

        if let viewModel = optViewModel {
            wireframe.present(viewModel: viewModel,
                              style: .alert,
                              from: view)
        }
    }

    func performAccountAction() {
        wireframe.showAccountsSelection(from: view)
    }

    func updateAmount(_ newValue: Decimal) {
        stateMachine.state.process(rewardEstimationAmount: newValue)
    }

    func selectAmountPercentage(_ percentage: Float) {
        if let balance = balance {
            let newAmount = balance * Decimal(Double(percentage))
            stateMachine.state.process(rewardEstimationAmount: newAmount)
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
        provideStakingInfo()
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

        logger?.debug("Did receive era stakers info: \(eraStakersInfo.era)")
    }

    func didReceive(eraStakersInfoError: Error) {
        handle(error: eraStakersInfoError)
    }

    func didReceive(newChain: Chain) {
        self.networkStakingInfo = nil

        stateMachine.state.process(chain: newChain)

        provideChain()
    }

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo
        provideStakingInfo()
    }

    func didReceive(networkStakingInfoError: Error) {
        handle(error: networkStakingInfoError)
    }

    func didReceive(payee: RewardDestinationArg?) {
        stateMachine.state.process(payee: payee)
    }

    func didReceive(payeeError: Error) {
        handle(error: payeeError)
    }

    func didFetchController(_ controller: AccountItem?) {
        guard let controller = controller else {

            if let view = view {
                let locale = view.localizationManager?.selectedLocale
                wireframe.presentMissingController(from: view, locale: locale)
            }

            return
        }

        let optExistingBonding: ExistingBonding? = stateMachine.viewState { (state: BondedState) in
            guard
                let chain = state.commonData.chain,
                let amount = Decimal.fromSubstrateAmount(state.ledgerInfo.active,
                                                         precision: chain.addressType.precision),
                let payee = state.payee,
                let rewardDestination = try? RewardDestination(payee: payee,
                                                               stashItem: state.stashItem,
                                                               chain: chain),
                controller.address == state.stashItem.controller else {

                return nil
            }

            return ExistingBonding(stashAddress: state.stashItem.stash,
                                   controllerAccount: controller,
                                   amount: amount,
                                   rewardDestination: rewardDestination)
        }

        if let existingBonding = optExistingBonding {
            wireframe.showRecommendedValidators(from: view, existingBonding: existingBonding)
        }
    }

    func didReceive(fetchControllerError: Error) {
        handle(error: fetchControllerError)
    }
}
