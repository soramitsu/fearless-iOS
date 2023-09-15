// swiftlint:disable file_length
import Foundation
import CommonWallet
import BigInt
import SwiftUI
import SoraFoundation
import SSFModels

final class StakingMainPresenter {
    weak var view: StakingMainViewProtocol?
    var wireframe: StakingMainWireframeProtocol!
    var interactor: StakingMainInteractorInputProtocol!
    private var selectedMetaAccount: MetaAccountModel

    let networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol
    let viewModelFacade: StakingViewModelFacadeProtocol
    let logger: LoggerProtocol?

    let dataValidatingFactory: StakingDataValidatingFactoryProtocol

    private var stateViewModelFactory: StakingStateViewModelFactoryProtocol
    private var stateMachine: StakingStateMachineProtocol
    private weak var moduleOutput: StakingMainModuleOutput?

    var chainAsset: ChainAsset? {
        stateMachine.viewState { (state: BaseStakingState) in state.commonData.chainAsset }
    }

    var amount: Decimal? {
        if let amount = stateMachine.viewState(
            using: { (state: ParachainState) in state.rewardEstimationAmount }
        ) {
            return amount
        }

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
    private var controllerAccount: ChainAccountResponse?
    private var nomination: Nomination?

    private var setupDone: Bool = false

    init(
        stateViewModelFactory: StakingStateViewModelFactoryProtocol,
        networkInfoViewModelFactory: NetworkInfoViewModelFactoryProtocol,
        viewModelFacade: StakingViewModelFacadeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        logger: LoggerProtocol?,
        selectedMetaAccount: MetaAccountModel,
        moduleOutput: StakingMainModuleOutput?
    ) {
        self.stateViewModelFactory = stateViewModelFactory
        self.networkInfoViewModelFactory = networkInfoViewModelFactory
        self.viewModelFacade = viewModelFacade
        self.logger = logger
        self.selectedMetaAccount = selectedMetaAccount

        let stateMachine = StakingStateMachine()
        self.stateMachine = stateMachine

        self.dataValidatingFactory = dataValidatingFactory

        stateMachine.delegate = self
        self.moduleOutput = moduleOutput
    }

    private func provideStakingInfo() {
        let commonData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }

        if let chainAsset = commonData?.chainAsset, let networkStakingInfo = networkStakingInfo {
            let networkStakingInfoViewModel = networkInfoViewModelFactory
                .createNetworkStakingInfoViewModel(
                    with: networkStakingInfo,
                    chainAsset: chainAsset,
                    minNominatorBond: commonData?.minNominatorBond,
                    priceData: commonData?.price,
                    selectedMetaAccount: selectedMetaAccount
                )
            view?.didRecieveNetworkStakingInfo(viewModel: networkStakingInfoViewModel)
        } else {
            view?.didRecieveNetworkStakingInfo(viewModel: nil)
        }
    }

    private func provideState() {
        let state = stateViewModelFactory.createViewModel(from: stateMachine.state)
        DispatchQueue.main.async {
            self.view?.didReceiveStakingState(viewModel: state)
        }
    }

    private func provideMainViewModel() {
        let commonData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }

        guard let address = commonData?.address, let chainAsset = commonData?.chainAsset else {
            return
        }

        let viewModel = networkInfoViewModelFactory.createMainViewModel(
            from: address,
            chainAsset: chainAsset,
            balance: balance ?? 0.0,
            selectedMetaAccount: selectedMetaAccount
        )

        view?.didReceive(viewModel: viewModel)
    }

    func setupValidators(for bondedState: BondedState) {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        DataValidationRunner(validators: [
            dataValidatingFactory.has(
                controller: controllerAccount,
                for: bondedState.stashItem.controller,
                locale: locale
            )
        ]).runValidation { [weak self] in
            guard
                let selectedAccount = SelectedWalletSettings.shared.value,
                let chainAsset = bondedState.commonData.chainAsset,
                let amount = Decimal.fromSubstrateAmount(
                    bondedState.ledgerInfo.active,
                    precision: Int16(chainAsset.asset.precision)
                ),
                let payee = bondedState.payee,
                let rewardDestination = try? RewardDestination(
                    payee: payee,
                    stashItem: bondedState.stashItem,
                    chainFormat: chainAsset.chain.chainFormat
                ),
                let controllerAccount = self?.controllerAccount,
                controllerAccount.toAddress() == bondedState.stashItem.controller
            else {
                return
            }

            let existingBonding = ExistingBonding(
                stashAddress: bondedState.stashItem.stash,
                controllerAccount: controllerAccount,
                amount: amount,
                rewardDestination: rewardDestination,
                selectedTargets: nil
            )

            self?.wireframe.proceedToSelectValidatorsStart(
                from: self?.view,
                existingBonding: existingBonding,
                chain: chainAsset.chain,
                asset: chainAsset.asset,
                selectedAccount: selectedAccount
            )
        }
    }
}

// MARK: - StakingMainPresenterProtocol

extension StakingMainPresenter: StakingMainPresenterProtocol {
    func didTriggerViewWillAppear() {
        interactor.changeActiveState(true)
    }

    func didTriggerViewWillDisappear() {
        interactor.changeActiveState(false)
    }

    func setup() {
        if setupDone {
            return
        }

        provideState()
        provideMainViewModel()
        provideStakingInfo()

        interactor.setup()

        setupDone = true
    }

    func performAssetSelection() {
        wireframe.showChainAssetSelection(
            from: view,
            selectedChainAsset: chainAsset,
            delegate: self
        )
    }

    func performMainAction() {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chainAsset = chainAsset,
            let commonData = stateMachine
            .viewState(using: { (state: BaseStakingState) in state })?.commonData else {
            return
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let nomination = stateMachine.viewState(
            using: { (state: NominatorState) in state }
        )?.nomination

        DataValidationRunner(validators: [
            dataValidatingFactory.maxNominatorsCountNotApplied(
                counterForNominators: commonData.counterForNominators,
                maxNominatorsCount: commonData.maxNominatorsCount,
                hasExistingNomination: nomination != nil,
                locale: locale
            )
        ]).runValidation { [weak self] in
            self?.wireframe.showSetupAmount(
                from: self?.view,
                amount: self?.amount,
                chain: chainAsset.chain,
                asset: chainAsset.asset,
                selectedAccount: selectedAccount,
                rewardChainAsset: commonData.rewardChainAsset
            )
        }
    }

    func performParachainMainAction(for delegation: ParachainStakingDelegationInfo) {
        let managedItems: [StakingManageOption] = {
            [.parachainStakingBalance(info: delegation), .yourCollator(info: delegation)]
        }()

        wireframe.showManageStaking(
            from: view,
            items: managedItems,
            delegate: self,
            context: managedItems as NSArray
        )
    }

    func performNominationStatusAction() {
        let optViewModel: SheetAlertPresentableViewModel? = {
            let locale = view?.localizationManager?.selectedLocale

            if let nominatorState = stateMachine.viewState(using: { (state: NominatorState) in state }) {
                return nominatorState.createStatusPresentableViewModel(locale: locale)
            }

            if let bondedState = stateMachine.viewState(using: { (state: BondedState) in state }) {
                return bondedState.createStatusPresentableViewModel(locale: locale)
            }

            return nil
        }()

        if let viewModel = optViewModel {
            wireframe.present(
                viewModel: viewModel,
                from: view
            )
        }
    }

    func performValidationStatusAction() {
        let optViewModel: SheetAlertPresentableViewModel? = stateMachine.viewState { (state: ValidatorState) in
            let locale = view?.localizationManager?.selectedLocale
            return state.createStatusPresentableViewModel(for: locale)
        }

        if let viewModel = optViewModel {
            wireframe.present(
                viewModel: viewModel,
                from: view
            )
        }
    }

    func performDelegationStatusAction() {}

    func performAccountAction() {
        wireframe.showAccountsSelection(from: view, moduleOutput: self)
    }

    func performManageStakingAction() {
        let managedItems: [StakingManageOption] = {
            if let nominatorState = stateMachine.viewState(using: { (state: NominatorState) in state }) {
                var options: [StakingManageOption] = []
                options.append(.stakingBalance)
                if nominatorState.commonData.chainAsset?.chain.externalApi?.staking != nil {
                    options.append(.pendingRewards)
                }
                options.append(.rewardDestination)
                options.append(.changeValidators(count: nominatorState.nomination.uniqueTargets.count))
                options.append(.controllerAccount)
                return options
            }

            if stateMachine.viewState(using: { (state: BondedState) in state }) != nil {
                return [
                    .stakingBalance,
                    .setupValidators,
                    .rewardDestination,
                    .controllerAccount
                ]
            }

            var options: [StakingManageOption] = []
            options.append(.stakingBalance)
            if chainAsset?.chain.externalApi?.staking != nil {
                options.append(.pendingRewards)
            }
            options.append(.rewardDestination)
            options.append(.yourValidator)
            options.append(.controllerAccount)
            return options
        }()

        wireframe.showManageStaking(
            from: view,
            items: managedItems,
            delegate: self,
            context: managedItems as NSArray
        )
    }

    func performParachainManageStakingAction(for delegation: ParachainStakingDelegationInfo) {
        guard let chainAsset = chainAsset else {
            return
        }

        wireframe.showStakingBalance(
            from: view,
            chainAsset: chainAsset,
            wallet: selectedMetaAccount,
            flow: .parachain(delegation: delegation.delegation, collator: delegation.collator)
        )
    }

    func performRewardInfoAction() {
        guard let rewardCalculator = stateMachine
            .viewState(using: { (state: BaseStakingState) in state })?.commonData.calculatorEngine else {
            return
        }

        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        let maxReward = rewardCalculator.calculatorReturn(isCompound: true, period: .year, type: .max())
        let avgReward = rewardCalculator.calculatorReturn(isCompound: true, period: .year, type: .avg)
        let maxRewardTitle = rewardCalculator.maxEarningsTitle(locale: locale)
        let avgRewardTitle = rewardCalculator.avgEarningTitle(locale: locale)

        wireframe.showRewardDetails(
            from: view,
            maxReward: (maxRewardTitle, maxReward),
            avgReward: (avgRewardTitle, avgReward)
        )
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
        guard let chainAsset = chainAsset else {
            return
        }

        wireframe.showStories(from: view, startingFrom: index, chainAsset: chainAsset)
    }

    func performChangeValidatorsAction() {
        guard
            let wallet = SelectedWalletSettings.shared.value,
            let chainAsset = chainAsset else {
            return
        }

        wireframe.showNominatorValidators(
            from: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    func performSetupValidatorsForBondedAction() {
        guard let bonded = stateMachine.viewState(using: { (state: BondedState) in state }) else {
            return
        }

        setupValidators(for: bonded)
    }

    func performBondMoreAction() {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chainAsset = chainAsset else {
            return
        }

        wireframe.showBondMore(
            from: view,
            chainAsset: chainAsset,
            wallet: selectedAccount,
            flow: .relaychain
        )
    }

    func performRedeemAction() {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let view = view,
            let chainAsset = chainAsset else { return }
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

        wireframe.showRedeem(
            from: view,
            chainAsset: chainAsset,
            wallet: selectedAccount,
            flow: .relaychain
        )
    }

    func performAnalyticsAction() {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value,
            let chainAsset = chainAsset else {
            return
        }
        let isNominator: AnalyticsContainerViewMode = {
            if stateMachine.viewState(using: { (state: ValidatorState) in state }) != nil {
                return .none
            }

            if stateMachine.viewState(using: { (state: BaseStashNextState) in state }) != nil {
                return .accountIsNominator
            }
            return .none
        }()

        let includeValidators: AnalyticsContainerViewMode = {
            if stateMachine.viewState(using: { (state: ValidatorState) in state }) != nil {
                return .none
            }
            return nomination != nil ? .includeValidatorsTab : .none
        }()

        let flow: AnalyticsRewardsFlow = chainAsset.stakingType?.isParachain == true ? .parachain : .relaychain

        wireframe.showAnalytics(
            from: view,
            mode: isNominator.union(includeValidators),
            chainAsset: chainAsset,
            wallet: selectedAccount,
            flow: flow
        )
    }

    func networkInfoViewDidChangeExpansion(isExpanded: Bool) {
        interactor.saveNetworkInfoViewExpansion(isExpanded: isExpanded)
    }
}

extension StakingMainPresenter: StakingStateMachineDelegate {
    func stateMachineDidChangeState(_: StakingStateMachineProtocol) {
        provideState()
    }
}

extension StakingMainPresenter: StakingMainInteractorOutputProtocol {
    func didReceive(selectedWallet: MetaAccountModel) {
        selectedMetaAccount = selectedWallet
    }

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
        if let availableValue = accountInfo?.data.stakingAvailable, let chainAsset = chainAsset {
            balance = Decimal.fromSubstrateAmount(
                availableValue,
                precision: Int16(chainAsset.asset.precision)
            )
        } else {
            balance = 0.0
        }

        stateMachine.state.process(accountInfo: accountInfo)

        provideMainViewModel()
    }

    func didReceive(balanceError: Error) {
        handle(error: balanceError)
    }

    func didReceive(selectedAddress: String) {
        stateMachine.state.process(address: selectedAddress)

        provideMainViewModel()
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
        self.nomination = nomination
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

    func didReceive(eraStakersInfo: EraStakersInfo) {
        stateMachine.state.process(eraStakersInfo: eraStakersInfo)

        logger?.debug("Did receive era stakers info: \(eraStakersInfo.activeEra)")
    }

    func didReceive(eraStakersInfoError: Error) {
        handle(error: eraStakersInfoError)
    }

    func didReceive(newChainAsset: ChainAsset) {
        networkStakingInfo = nil

        stateMachine.state.process(chainAsset: newChainAsset)

        provideMainViewModel()
        provideStakingInfo()

        if let stories = StoriesFactory().createModel(for: newChainAsset.stakingType) {
            view?.didReceive(stories: stories)
        }
    }

    func didReceive(networkStakingInfo: NetworkStakingInfo) {
        self.networkStakingInfo = networkStakingInfo

        let commondData = stateMachine.viewState { (state: BaseStakingState) in state.commonData }
        let minStake = networkStakingInfo.calculateMinimumStake(given: commondData?.minNominatorBond)
        stateMachine.state.process(minStake: minStake)
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

    func didReceiveControllerAccount(result: Result<ChainAccountResponse?, Error>) {
        switch result {
        case let .success(accountItem):
            controllerAccount = accountItem
        case let .failure(error):
            controllerAccount = nil
            handle(error: error)
        }
    }

    func didReceiveMaxNominatorsPerValidator(result: Result<UInt32, Error>) {
        switch result {
        case let .success(maxNominatorsPerValidator):
            stateMachine.state.process(maxNominatorsPerValidator: maxNominatorsPerValidator)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceieve(subqueryRewards: Result<[SubqueryRewardItemData]?, Error>, period: AnalyticsPeriod) {
        switch subqueryRewards {
        case let .success(rewards):
            guard let chainAsset = chainAsset else {
                return
            }

            stateMachine.state.process(subqueryRewards: (rewards, period))
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMinNominatorBond(result: Result<BigUInt?, Error>) {
        switch result {
        case let .success(minNominatorBond):
            stateMachine.state.process(minNominatorBond: minNominatorBond)

            if let networkStakingInfo = networkStakingInfo {
                let minStake = networkStakingInfo.calculateMinimumStake(
                    given: minNominatorBond
                )

                stateMachine.state.process(minStake: minStake)
            }

            provideStakingInfo()

        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveCounterForNominators(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(counterForNominators):
            stateMachine.state.process(counterForNominators: counterForNominators)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceiveMaxNominatorsCount(result: Result<UInt32?, Error>) {
        switch result {
        case let .success(maxNominatorsCount):
            stateMachine.state.process(maxNominatorsCount: maxNominatorsCount)
        case let .failure(error):
            handle(error: error)
        }
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case let .success(eraCountdown):
            stateMachine.state.process(eraCountdown: eraCountdown)
        case let .failure(error):
            handle(error: error)
        }
    }

    func networkInfoViewExpansion(isExpanded: Bool) {
        view?.expandNetworkInfoView(isExpanded)
    }

//    Parachain

    func didReceive(delegationInfos: [ParachainStakingDelegationInfo]?) {
        stateMachine.state.process(delegationInfos: delegationInfos)
    }

    func didReceiveScheduledRequests(requests: [AccountAddress: [ParachainStakingScheduledRequest]]?) {
        stateMachine.state.process(scheduledRequests: requests)
    }

    func didReceiveTopDelegations(delegations: [AccountAddress: ParachainStakingDelegations]?) {
        stateMachine.state.process(topDelegations: delegations)
    }

    func didReceiveBottomDelegations(delegations: [AccountAddress: ParachainStakingDelegations]?) {
        stateMachine.state.process(bottomDelegations: delegations)
    }

    func didReceiveRound(round: ParachainStakingRoundInfo?) {
        stateMachine.state.process(roundInfo: round)
    }

    func didReceiveCurrentBlock(currentBlock: UInt32?) {
        stateMachine.state.process(currentBlock: currentBlock)
    }

    func didReceive(rewardChainAsset: ChainAsset?) {
        stateMachine.state.process(rewardChainAsset: rewardChainAsset)
    }

    func didReceive(rewardAssetPrice: PriceData?) {
        stateMachine.state.process(rewardAssetPrice: rewardAssetPrice)
    }
}

// MARK: - ModalPickerViewControllerDelegate

extension StakingMainPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let view = view,
            let selectedAccount = SelectedWalletSettings.shared.value,
            let manageStakingItems = context as? [StakingManageOption],
            index >= 0,
            index < manageStakingItems.count,
            let chainAsset = chainAsset,
            let commonData = stateMachine
            .viewState(using: { (state: BaseStakingState) in state })?.commonData
        else {
            return
        }

        let selectedItem = manageStakingItems[index]

        switch selectedItem {
        case .pendingRewards:
            if let validatorState = stateMachine.viewState(using: { (state: ValidatorState) in state }) {
                let stashAddress = validatorState.stashItem.stash
                wireframe.showRewardPayoutsForValidator(
                    from: view,
                    stashAddress: stashAddress,
                    chain: chainAsset.chain,
                    asset: chainAsset.asset,
                    selectedAccount: selectedAccount
                )
                return
            }

            if let stashState = stateMachine.viewState(using: { (state: BaseStashNextState) in state }) {
                let stashAddress = stashState.stashItem.stash
                wireframe.showRewardPayoutsForNominator(
                    from: view,
                    stashAddress: stashAddress,
                    chain: chainAsset.chain,
                    asset: chainAsset.asset,
                    selectedAccount: selectedAccount
                )
                return
            }
        case .rewardDestination:
            wireframe.showRewardDestination(
                from: view,
                chain: chainAsset.chain,
                asset: chainAsset.asset,
                selectedAccount: selectedAccount,
                rewardChainAsset: commonData.rewardChainAsset
            )
        case .stakingBalance:
            wireframe.showStakingBalance(
                from: view,
                chainAsset: chainAsset,
                wallet: selectedAccount,
                flow: .relaychain
            )
        case .changeValidators:
            wireframe.showNominatorValidators(
                from: view,
                chainAsset: chainAsset,
                wallet: selectedAccount
            )
        case .setupValidators:
            if let bondedState = stateMachine.viewState(using: { (state: BondedState) in state }) {
                setupValidators(for: bondedState)
            }
        case .controllerAccount:
            wireframe.showControllerAccount(
                from: view,
                chain: chainAsset.chain,
                asset: chainAsset.asset,
                selectedAccount: selectedAccount
            )
        case .yourValidator:
            if let validatorState = stateMachine.viewState(using: { (state: ValidatorState) in state }) {
                let stashAddress = validatorState.stashItem.stash
                wireframe.showYourValidatorInfo(
                    chainAsset: chainAsset,
                    selectedAccount: selectedAccount,
                    flow: .relaychain(
                        validatorInfo: nil,
                        address: stashAddress
                    ),
                    from: view
                )
            }
        case let .yourCollator(info):
            wireframe.showYourValidatorInfo(
                chainAsset: chainAsset,
                selectedAccount: selectedAccount,
                flow: .parachain(candidate: info.collator),
                from: view
            )
        case let .parachainStakingBalance(info):
            wireframe.showStakingBalance(
                from: view,
                chainAsset: chainAsset,
                wallet: selectedAccount,
                flow: .parachain(delegation: info.delegation, collator: info.collator)
            )
        }
    }
}

extension StakingMainPresenter: AssetSelectionDelegate {
    func assetSelection(
        view _: ChainSelectionViewProtocol,
        didCompleteWith chainAsset: ChainAsset,
        context: Any?
    ) {
        guard let type = context as? AssetSelectionStakingType, let chainAsset = type.chainAsset else {
            return
        }

        interactor.save(chainAsset: chainAsset)

        switch type {
        case .normal:
            break
        case .pool:
            moduleOutput?.didSwitchStakingType(type)
        }
    }
}

extension StakingMainPresenter: WalletsManagmentModuleOutput {
    func showAddNewWallet() {
        wireframe.showCreateNewWallet(from: view)
    }

    func showImportWallet(defaultSource: AccountImportSource) {
        wireframe.showImportWallet(defaultSource: defaultSource, from: view)
    }

    func showImportGoogle() {
        wireframe.showBackupSelectWallet(from: view)
    }

    func showGetPreinstalledWallet() {
        wireframe.showGetPreinstalledWallet(from: view)
    }
}
