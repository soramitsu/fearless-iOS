import BigInt
import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class StakingMainTests: XCTestCase {
    override func tearDown() {
        SelectedWalletSettings.shared.internalValue = nil
        super.tearDown()
    }

    func testSetupAndLifecycle_whenTriggered_thenCallsInteractorOnceAndPersistsExpansion() {
        let fixture = makeFixture()

        fixture.presenter.setup()
        fixture.presenter.setup()
        fixture.presenter.didTriggerViewWillAppear()
        fixture.presenter.didTriggerViewWillDisappear()
        fixture.presenter.networkInfoViewDidChangeExpansion(isExpanded: true)

        XCTAssertEqual(fixture.interactor.setupCallCount, 1)
        XCTAssertEqual(fixture.interactor.activeStates, [true, false])
        XCTAssertEqual(fixture.interactor.savedNetworkExpansion, true)
    }

    func testChainAssetAndAddressUpdates_thenProvideMainViewAndAssetActions() {
        let fixture = makeFixture()

        fixture.prepareBaseState()
        fixture.presenter.performAssetSelection()
        fixture.presenter.performAccountAction()
        fixture.presenter.selectStory(at: 2)

        XCTAssertEqual(fixture.view.mainViewModel?.address, WestendStub.address)
        XCTAssertEqual(fixture.wireframe.selectedChainAsset?.asset.id, fixture.chainAsset.asset.id)
        XCTAssertTrue(fixture.wireframe.accountsSelectionOutput === fixture.presenter)
        XCTAssertEqual(fixture.wireframe.storyIndex, 2)
    }

    func testAssetSelection_whenNormalAndPoolSelected_thenSavesAndNotifiesPoolSwitch() {
        let fixture = makeFixture()
        let selectionView = ChainSelectionViewSpy()

        fixture.presenter.assetSelection(
            view: selectionView,
            didCompleteWith: fixture.chainAsset,
            context: AssetSelectionStakingType.normal(chainAsset: fixture.chainAsset)
        )
        fixture.presenter.assetSelection(
            view: selectionView,
            didCompleteWith: fixture.chainAsset,
            context: AssetSelectionStakingType.pool(chainAsset: fixture.chainAsset)
        )

        XCTAssertEqual(fixture.interactor.savedChainAssets.map(\.asset.id), ["unit", "unit"])
        XCTAssertEqual(fixture.moduleOutput.switchedTypes.count, 1)
    }

    func testManageStaking_whenNominatorState_thenBuildsOptionsAndRoutesSelections() throws {
        let fixture = makeFixture()
        fixture.prepareNominatorState()

        fixture.presenter.performManageStakingAction()

        let items = try XCTUnwrap(fixture.wireframe.manageItems)
        XCTAssertTrue(items.containsStakingBalance)
        XCTAssertTrue(items.containsChangeValidators)
        XCTAssertTrue(items.containsRewardDestination)
        XCTAssertTrue(items.containsControllerAccount)

        fixture.presenter.modalPickerDidSelectModelAtIndex(
            try XCTUnwrap(items.firstIndexOfStakingBalance),
            context: items as NSArray
        )
        fixture.presenter.modalPickerDidSelectModelAtIndex(
            try XCTUnwrap(items.firstIndexOfChangeValidators),
            context: items as NSArray
        )
        fixture.presenter.modalPickerDidSelectModelAtIndex(
            try XCTUnwrap(items.firstIndexOfRewardDestination),
            context: items as NSArray
        )

        XCTAssertEqual(fixture.wireframe.didShowStakingBalance, 1)
        XCTAssertEqual(fixture.wireframe.didShowNominatorValidators, 1)
        XCTAssertEqual(fixture.wireframe.didShowRewardDestination, 1)
    }

    func testDirectActions_whenBaseStatePrepared_thenRouteThroughWireframe() {
        let fixture = makeFixture()
        fixture.prepareBaseState()

        fixture.presenter.performBondMoreAction()
        fixture.presenter.performAnalyticsAction()
        fixture.presenter.performChangeValidatorsAction()

        XCTAssertEqual(fixture.wireframe.didShowBondMore, 1)
        XCTAssertEqual(fixture.wireframe.didShowAnalytics, 1)
        XCTAssertEqual(fixture.wireframe.didShowNominatorValidators, 1)
    }

    func testStateViewModelFactory_whenInjectedEventCenterPublishesMetaAccountChange_thenUpdatesCurrency() throws {
        let selectedAccount = AccountGenerator.generateMetaAccount().replacingCurrency(.defaultCurrency())
        let eventCenter = StakingMainEventCenterSpy()
        let chainAsset = makePricedChainAsset()
        let stateMachine = StakingStateMachineSpy()
        let commonData = StakingStateCommonData.empty
            .byReplacing(chainAsset: chainAsset)
            .byReplacing(accountInfo: WestendStub.accountInfo.item)
        let state = NoStashState(
            stateMachine: stateMachine,
            commonData: commonData,
            rewardEstimationAmount: 3
        )
        let factory = StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: { _, _ in AnalyticsRewardsViewModelFactoryStub() },
            logger: LoggerSpy(),
            selectedMetaAccount: selectedAccount,
            eventCenter: eventCenter
        )
        let locale = Locale(identifier: "en_US")

        let usdState = factory.createViewModel(from: state)
        let usdPrice = try XCTUnwrap(usdState.noStashViewModel?.assetBalance.value(for: locale).price)
        eventCenter.notify(with: MetaAccountModelChangedEvent(account: selectedAccount.replacingCurrency(.euro())))
        let euroState = factory.createViewModel(from: state)
        let euroPrice = try XCTUnwrap(euroState.noStashViewModel?.assetBalance.value(for: locale).price)

        XCTAssertGreaterThanOrEqual(eventCenter.addedObservers.count, 2)
        XCTAssertTrue(usdPrice.contains(Currency.defaultCurrency().symbol))
        XCTAssertTrue(euroPrice.contains(Currency.euro().symbol))
    }

    private func makeFixture() -> StakingMainFixture {
        let wallet = AccountGenerator.generateMetaAccount()
        SelectedWalletSettings.shared.internalValue = wallet

        let chainAsset = makeChainAsset()
        let wireframe = StakingMainWireframeSpy()
        let interactor = StakingMainInteractorInputSpy()
        let moduleOutput = StakingMainModuleOutputSpy()
        let presenter = StakingMainPresenter(
            stateViewModelFactory: StakingStateViewModelFactorySpy(),
            networkInfoViewModelFactory: NetworkInfoViewModelFactorySpy(),
            viewModelFacade: StakingViewModelFacade(selectedMetaAccount: wallet),
            dataValidatingFactory: StakingDataValidatingFactory(presentable: wireframe),
            logger: LoggerSpy(),
            selectedMetaAccount: wallet,
            moduleOutput: moduleOutput
        )
        let view = StakingMainViewSpy()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        return StakingMainFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            view: view,
            moduleOutput: moduleOutput,
            chainAsset: chainAsset
        )
    }

    private func makeChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            staking: .relayChain
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal
        )
        chain.assets = [asset]

        return ChainAsset(chain: chain, asset: asset)
    }

    private func makePricedChainAsset() -> ChainAsset {
        let chain = ChainModelGenerator.generateChain(
            generatingAssets: 0,
            addressPrefix: 42,
            assetPresicion: 12,
            staking: .relayChain
        )
        let asset = AssetModel(
            id: "unit",
            name: "Unit",
            symbol: "UNIT",
            precision: 12,
            price: 2,
            fiatDayChange: nil,
            isUtility: true,
            isNative: true,
            staking: .relayChain,
            type: .normal,
            coingeckoPriceId: "unit"
        )
        chain.assets = [asset]

        return ChainAsset(chain: chain, asset: asset)
    }
}

private struct StakingMainFixture {
    let presenter: StakingMainPresenter
    let interactor: StakingMainInteractorInputSpy
    let wireframe: StakingMainWireframeSpy
    let view: StakingMainViewSpy
    let moduleOutput: StakingMainModuleOutputSpy
    let chainAsset: ChainAsset

    func prepareBaseState() {
        presenter.didReceive(newChainAsset: chainAsset)
        presenter.didReceive(selectedAddress: WestendStub.address)
        presenter.didReceive(accountInfo: WestendStub.accountInfo.item)
    }

    func prepareNominatorState() {
        prepareBaseState()
        presenter.didReceive(stashItem: StashItem(stash: WestendStub.address, controller: WestendStub.address))
        presenter.didReceive(ledgerInfo: WestendStub.ledgerInfo.item)
        presenter.didReceive(nomination: WestendStub.nomination.item)
        presenter.didReceive(payee: .staked)
    }
}

private final class StakingMainInteractorInputSpy: StakingMainInteractorInputProtocol {
    private(set) var setupCallCount = 0
    private(set) var activeStates: [Bool] = []
    private(set) var savedNetworkExpansion: Bool?
    private(set) var savedChainAssets: [ChainAsset] = []

    func setup() {
        setupCallCount += 1
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        savedNetworkExpansion = isExpanded
    }

    func save(chainAsset: ChainAsset) {
        savedChainAssets.append(chainAsset)
    }

    func changeActiveState(_ isActive: Bool) {
        activeStates.append(isActive)
    }
}

private final class StakingMainViewSpy: StakingMainViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    private(set) var mainViewModel: StakingMainViewModel?
    private(set) var networkInfoViewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?
    private(set) var stakingState: StakingViewState?
    private(set) var expandedNetworkInfo: Bool?
    private(set) var estimationViewModel: StakingEstimationViewModel?
    private(set) var stories: LocalizableResource<StoriesModel>?

    func didReceive(viewModel: StakingMainViewModel) {
        mainViewModel = viewModel
    }

    func didRecieveNetworkStakingInfo(viewModel: LocalizableResource<NetworkStakingInfoViewModelProtocol>?) {
        networkInfoViewModel = viewModel
    }

    func didReceiveStakingState(viewModel: StakingViewState) {
        stakingState = viewModel
    }

    func expandNetworkInfoView(_ isExpanded: Bool) {
        expandedNetworkInfo = isExpanded
    }

    func didReceive(stakingEstimationViewModel: StakingEstimationViewModel) {
        estimationViewModel = stakingEstimationViewModel
    }

    func didReceive(stories: LocalizableResource<StoriesModel>) {
        self.stories = stories
    }

    func applyLocalization() {}
}

private final class StakingStateViewModelFactorySpy: StakingStateViewModelFactoryProtocol {
    func createViewModel(from _: StakingStateProtocol) -> StakingViewState {
        .undefined
    }
}

private final class AnalyticsRewardsViewModelFactoryStub: AnalyticsRewardsViewModelFactoryProtocol {
    func createViewModel(
        from _: [SubqueryRewardItemData],
        priceData _: PriceData?,
        period _: AnalyticsPeriod,
        selectedChartIndex _: Int?,
        hasPendingRewards _: Bool
    ) -> LocalizableResource<AnalyticsRewardsViewModel> {
        LocalizableResource { _ in fatalError("Unused analytics factory stub") }
    }
}

private final class StakingMainEventCenterSpy: EventCenterProtocol {
    private(set) var addedObservers: [EventVisitorProtocol] = []

    func notify(with event: EventProtocol) {
        addedObservers.forEach { event.accept(visitor: $0) }
    }

    func add(observer: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {
        addedObservers.append(observer)
    }

    func remove(observer: EventVisitorProtocol) {
        addedObservers.removeAll { $0 === observer }
    }
}

private final class StakingStateMachineSpy: StakingStateMachineProtocol {
    var state: StakingStateProtocol

    init() {
        state = BaseStakingState(stateMachine: nil, commonData: .empty)
    }

    func transit(to state: StakingStateProtocol) {
        self.state = state
    }
}

private extension StakingViewState {
    var noStashViewModel: StakingEstimationViewModel? {
        if case let .noStash(viewModel, _) = self {
            return viewModel
        }

        return nil
    }
}

private final class NetworkInfoViewModelFactorySpy: NetworkInfoViewModelFactoryProtocol {
    func createMainViewModel(
        from address: AccountAddress,
        chainAsset: ChainAsset,
        balance _: Decimal,
        selectedMetaAccount _: MetaAccountModel
    ) -> StakingMainViewModel {
        StakingMainViewModel(
            address: address,
            chainName: chainAsset.chain.name,
            assetName: chainAsset.asset.symbol,
            assetIcon: nil,
            balanceViewModel: nil
        )
    }

    func createNetworkStakingInfoViewModel(
        with _: NetworkStakingInfo,
        chainAsset _: ChainAsset,
        minNominatorBond _: BigUInt?,
        priceData _: PriceData?,
        selectedMetaAccount _: MetaAccountModel
    ) -> LocalizableResource<NetworkStakingInfoViewModelProtocol> {
        LocalizableResource { _ in
            NetworkStakingInfoViewModel(
                totalStake: nil,
                minimalStake: nil,
                activeNominators: "0",
                lockUpPeriod: nil
            )
        }
    }
}

private final class StakingMainWireframeSpy: StakingMainWireframeProtocol {
    private(set) var selectedChainAsset: ChainAsset?
    private(set) weak var accountsSelectionOutput: WalletsManagmentModuleOutput?
    private(set) var storyIndex: Int?
    private(set) var manageItems: [StakingManageOption]?
    private(set) var didShowStakingBalance = 0
    private(set) var didShowNominatorValidators = 0
    private(set) var didShowRewardDestination = 0
    private(set) var didShowBondMore = 0
    private(set) var didShowAnalytics = 0
    private(set) var didShowControllerAccount = 0
    private(set) var didShowCreateNewWallet = 0
    private(set) var didShowImportWallet = 0
    private(set) var didShowBackupSelectWallet = 0
    private(set) var didShowGetPreinstalledWallet = 0

    func showSetupAmount(
        from _: StakingMainViewProtocol?,
        amount _: Decimal?,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel,
        rewardChainAsset _: ChainAsset?
    ) {}

    func showManageStaking(
        from _: StakingMainViewProtocol?,
        items: [StakingManageOption],
        delegate _: ModalPickerViewControllerDelegate?,
        context _: AnyObject?
    ) {
        manageItems = items
    }

    func proceedToSelectValidatorsStart(
        from _: StakingMainViewProtocol?,
        existingBonding _: ExistingBonding,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {}

    func showStories(
        from _: ControllerBackedProtocol?,
        startingFrom index: Int,
        chainAsset _: ChainAsset
    ) {
        storyIndex = index
    }

    func showRewardDetails(
        from _: ControllerBackedProtocol?,
        maxReward _: (title: String, amount: Decimal),
        avgReward _: (title: String, amount: Decimal)
    ) {}

    func showRewardPayoutsForNominator(
        from _: ControllerBackedProtocol?,
        stashAddress _: AccountAddress,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {}

    func showRewardPayoutsForValidator(
        from _: ControllerBackedProtocol?,
        stashAddress _: AccountAddress,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {}

    func showStakingBalance(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingBalanceFlow
    ) {
        didShowStakingBalance += 1
    }

    func showNominatorValidators(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        didShowNominatorValidators += 1
    }

    func showRewardDestination(
        from _: ControllerBackedProtocol?,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel,
        rewardChainAsset _: ChainAsset?
    ) {
        didShowRewardDestination += 1
    }

    func showControllerAccount(
        from _: ControllerBackedProtocol?,
        chain _: ChainModel,
        asset _: AssetModel,
        selectedAccount _: MetaAccountModel
    ) {
        didShowControllerAccount += 1
    }

    func showAccountsSelection(
        from _: StakingMainViewProtocol?,
        moduleOutput: WalletsManagmentModuleOutput
    ) {
        accountsSelectionOutput = moduleOutput
    }

    func showBondMore(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingBondMoreFlow
    ) {
        didShowBondMore += 1
    }

    func showRedeem(
        from _: ControllerBackedProtocol?,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: StakingRedeemConfirmationFlow
    ) {}

    func showAnalytics(
        from _: ControllerBackedProtocol?,
        mode _: AnalyticsContainerViewMode,
        chainAsset _: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: AnalyticsRewardsFlow
    ) {
        didShowAnalytics += 1
    }

    func showYourValidatorInfo(
        chainAsset _: ChainAsset,
        selectedAccount _: MetaAccountModel,
        flow _: ValidatorInfoFlow,
        from _: ControllerBackedProtocol?
    ) {}

    func showChainAssetSelection(
        from _: StakingMainViewProtocol?,
        selectedChainAsset: ChainAsset?,
        delegate _: AssetSelectionDelegate
    ) {
        self.selectedChainAsset = selectedChainAsset
    }

    func showCreateNewWallet(from _: ControllerBackedProtocol?) {
        didShowCreateNewWallet += 1
    }

    func showImportWallet(defaultSource _: AccountImportSource, from _: ControllerBackedProtocol?) {
        didShowImportWallet += 1
    }

    func showBackupSelectWallet(from _: ControllerBackedProtocol?) {
        didShowBackupSelectWallet += 1
    }

    func showGetPreinstalledWallet(from _: ControllerBackedProtocol?) {
        didShowGetPreinstalledWallet += 1
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private final class StakingMainModuleOutputSpy: StakingMainModuleOutput {
    private(set) var switchedTypes: [AssetSelectionStakingType] = []

    func didSwitchStakingType(_ type: AssetSelectionStakingType) {
        switchedTypes.append(type)
    }
}

private final class ChainSelectionViewSpy: ChainSelectionViewProtocol {
    let controller = UIViewController()
    let isSetup = true

    func didReload() {}
    func bind(viewModel _: TextSearchViewModel?) {}
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private extension [StakingManageOption] {
    var containsStakingBalance: Bool { contains(where: isStakingBalance) }
    var containsChangeValidators: Bool { contains(where: isChangeValidators) }
    var containsRewardDestination: Bool { contains(where: isRewardDestination) }
    var containsControllerAccount: Bool { contains(where: isControllerAccount) }

    var firstIndexOfStakingBalance: Int? {
        firstIndex(where: isStakingBalance)
    }

    var firstIndexOfChangeValidators: Int? {
        firstIndex(where: isChangeValidators)
    }

    var firstIndexOfRewardDestination: Int? {
        firstIndex(where: isRewardDestination)
    }

    private func isStakingBalance(_ option: StakingManageOption) -> Bool {
        if case .stakingBalance = option { return true }
        return false
    }

    private func isChangeValidators(_ option: StakingManageOption) -> Bool {
        if case .changeValidators = option { return true }
        return false
    }

    private func isRewardDestination(_ option: StakingManageOption) -> Bool {
        if case .rewardDestination = option { return true }
        return false
    }

    private func isControllerAccount(_ option: StakingManageOption) -> Bool {
        if case .controllerAccount = option { return true }
        return false
    }
}
