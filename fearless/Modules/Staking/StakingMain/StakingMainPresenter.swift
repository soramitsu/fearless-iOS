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
    private var controllerAccount: AccountItem?

    init(
        stateViewModelFactory: StakingStateViewModelFactoryProtocol,
        networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
        viewModelFacade: StakingViewModelFacadeProtocol,
        logger: LoggerProtocol?
    ) {
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

        if let chain = commonData?.chain, let networkStakingInfo = networkStakingInfo {
            let networkStakingInfoViewModel = networkInfoViewModelFactory
                .createNetworkStakingInfoViewModel(
                    with: networkStakingInfo,
                    chain: chain,
                    priceData: commonData?.price
                )
            view?.didRecieveNetworkStakingInfo(viewModel: networkStakingInfoViewModel)
        } else {
            view?.didRecieveNetworkStakingInfo(viewModel: nil)
        }
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
        guard let bondedState = stateMachine.viewState(using: { (state: BondedState) in state }) else {
            wireframe.showSetupAmount(from: view, amount: amount)
            return
        }

        guard let controllerAccount = controllerAccount else {
            if let view = view {
                let locale = view.localizationManager?.selectedLocale
                let controllerAddress = bondedState.stashItem.controller
                wireframe.presentMissingController(from: view, address: controllerAddress, locale: locale)
            }

            return
        }

        guard
            let chain = bondedState.commonData.chain,
            let amount = Decimal.fromSubstrateAmount(
                bondedState.ledgerInfo.active,
                precision: chain.addressType.precision
            ),
            let payee = bondedState.payee,
            let rewardDestination = try? RewardDestination(
                payee: payee,
                stashItem: bondedState.stashItem,
                chain: chain
            ),
            controllerAccount.address == bondedState.stashItem.controller
        else {
            return
        }

        let existingBonding = ExistingBonding(
            stashAddress: bondedState.stashItem.stash,
            controllerAccount: controllerAccount,
            amount: amount,
            rewardDestination: rewardDestination
        )
        wireframe.showRecommendedValidators(from: view, existingBonding: existingBonding)
    }

    func performNominationStatusAction() {
        let optViewModel: AlertPresentableViewModel? = stateMachine.viewState { (state: NominatorState) in
            let locale = view?.localizationManager?.selectedLocale
            return state.createStatusPresentableViewModel(
                for: networkStakingInfo?.minimalStake,
                locale: locale
            )
        }

        if let viewModel = optViewModel {
            wireframe.present(
                viewModel: viewModel,
                style: .alert,
                from: view
            )
        }
    }

    func performValidationStatusAction() {
        let optViewModel: AlertPresentableViewModel? = stateMachine.viewState { (state: ValidatorState) in
            let locale = view?.localizationManager?.selectedLocale
            return state.createStatusPresentableViewModel(for: locale)
        }

        if let viewModel = optViewModel {
            wireframe.present(
                viewModel: viewModel,
                style: .alert,
                from: view
            )
        }
    }

    func performAccountAction() {
        wireframe.showAccountsSelection(from: view)
    }

    func performManageStakingAction() {
        let managedItems: [StakingManageOption] = {
            if let nominatorState = stateMachine.viewState(using: { (state: NominatorState) in state }) {
                return [
                    .stakingBalance,
                    .rewardPayouts,
                    .rewardDestination,
                    .validators(count: nominatorState.nomination.targets.count),
                    .controllerAccount
                ]
            } else {
                return [
                    .stakingBalance,
                    .rewardPayouts,
                    .rewardDestination,
                    .controllerAccount
                ]
            }
        }()

        wireframe.showManageStaking(
            from: view,
            items: managedItems,
            delegate: self,
            context: managedItems as NSArray
        )
    }

    func performRewardInfoAction() {
        guard let rewardCalculator = stateMachine
            .viewState(using: { (state: BaseStakingState) in state })?.commonData.calculatorEngine else {
            return
        }

        let maxReward = rewardCalculator.calculateMaxReturn(isCompound: true, period: .year)
        let avgReward = rewardCalculator.calculateAvgReturn(isCompound: true, period: .year)

        wireframe.showRewardDetails(from: view, maxReward: maxReward, avgReward: avgReward)
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

    func selectStory(at index: Int) {
        wireframe.showStories(from: view, startingFrom: index)
    }

    func performChangeValidatorsAction() {
        if stateMachine.viewState(using: { (state: NominatorState) in state }) != nil {
            wireframe.showNominatorValidators(from: view)
        }
    }

    func performBondMoreAction() {
        wireframe.showBondMore(from: view)
    }

    func performRedeemAction() {
        guard let view = view else { return }
        let selectedLocale = view.localizationManager?.selectedLocale
        guard controllerAccount != nil else {
            let baseState = stateMachine.viewState(using: { (state: BaseStashNextState) in state })
            wireframe.presentMissingController(
                from: view,
                address: baseState?.stashItem.controller ?? "",
                locale: selectedLocale
            )
            return
        }
        wireframe.showRedeem(from: view)
    }
}

extension StakingMainPresenter: StakingStateMachineDelegate {
    func stateMachineDidChangeState(_: StakingStateMachineProtocol) {
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

    func didReceive(accountInfo: AccountInfo?) {
        if let availableValue = accountInfo?.data.available, let chain = chain {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: chain.addressType.precision
            )
        } else {
            balance = 0.0
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

    func didReceive(ledgerInfo: StakingLedger?) {
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
        case let .open(blockNumber):
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
        networkStakingInfo = nil

        stateMachine.state.process(chain: newChain)

        provideChain()
        provideStakingInfo()
    }

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo
        stateMachine.state.process(minimalStake: networkStakingInfo.minimalStake)
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

    func didFetchController(_ controller: AccountItem?, for _: AccountAddress) {
        controllerAccount = controller
    }

    func didReceive(fetchControllerError: Error) {
        controllerAccount = nil
        handle(error: fetchControllerError)
    }

    func didReceiveMaxNominatorsPerValidator(result: Result<UInt32, Error>) {
        switch result {
        case let .success(maxNominatorsPerValidator):
            stateMachine.state.process(maxNominatorsPerValidator: maxNominatorsPerValidator)
        case let .failure(error):
            handle(error: error)
        }
    }
}

extension StakingMainPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let manageStakingItems = context as? [StakingManageOption],
            index >= 0, index < manageStakingItems.count else {
            return
        }

        let selectedItem = manageStakingItems[index]

        switch selectedItem {
        case .rewardPayouts:
            if let validatorState = stateMachine.viewState(using: { (state: ValidatorState) in state }) {
                let stashAddress = validatorState.stashItem.stash
                wireframe.showRewardPayoutsForValidator(from: view, stashAddress: stashAddress)
                return
            }

            if let stashState = stateMachine.viewState(using: { (state: BaseStashNextState) in state }) {
                let stashAddress = stashState.stashItem.stash
                wireframe.showRewardPayoutsForNominator(from: view, stashAddress: stashAddress)
                return
            }
        case .rewardDestination:
            wireframe.showRewardDestination(from: view)
        case .stakingBalance:
            wireframe.showStakingBalance(from: view)
        case .validators:
            if stateMachine.viewState(using: { (state: NominatorState) in state }) != nil {
                wireframe.showNominatorValidators(from: view)
            }
        case .controllerAccount:
            wireframe.showControllerAccount(from: view)
        }
    }
}
