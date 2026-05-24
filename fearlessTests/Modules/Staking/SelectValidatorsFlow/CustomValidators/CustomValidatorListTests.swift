import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CustomValidatorListTests: XCTestCase {
    func testSetup_thenWiresStateAndReloadsViewModel() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertEqual(fixture.view.filterAppliedState, fixture.state.filterApplied)
        XCTAssertEqual(fixture.view.viewModel?.sections.first?.cells.count, 2)
        XCTAssertEqual(fixture.state.updatedViewModel?.selectedValidatorsCount, 1)
    }

    func testSearchTextDidChange_thenRebuildsViewModelWithSearchText() {
        let fixture = makeFixture()

        fixture.presenter.searchTextDidChange("alice")

        XCTAssertEqual(fixture.viewModelFactory.lastSearchText, "alice")
        XCTAssertNotNil(fixture.view.viewModel)
    }

    func testHeaderActions_thenForwardToState() {
        let fixture = makeFixture()

        fixture.presenter.fillWithRecommended()
        fixture.presenter.changeIdentityFilterValue()
        fixture.presenter.changeMinBondFilterValue()
        fixture.presenter.clearFilter()

        XCTAssertTrue(fixture.state.didFillWithRecommended)
        XCTAssertTrue(fixture.state.didChangeIdentityFilter)
        XCTAssertTrue(fixture.state.didChangeMinBondFilter)
        XCTAssertTrue(fixture.state.didClearFilter)
        XCTAssertNotNil(fixture.view.viewModel)
    }

    func testSelectionAndRemovalActions_thenForwardToState() {
        let fixture = makeFixture()
        let validator = SelectedValidatorInfo(address: WestendStub.address)

        fixture.presenter.changeValidatorSelection(address: WestendStub.address)
        fixture.presenter.didRemove(validator)
        fixture.presenter.didRemove(validatorAddress: WestendStub.address)
        fixture.presenter.proceed()

        XCTAssertEqual(fixture.state.selectedAddress, WestendStub.address)
        XCTAssertEqual(fixture.state.removedValidator?.address, WestendStub.address)
        XCTAssertEqual(fixture.state.removedAddress, WestendStub.address)
        XCTAssertTrue(fixture.state.didProceed)
    }

    func testPresentingActions_thenRouteWithExpectedContext() {
        let fixture = makeFixture()

        fixture.presenter.didSelectValidator(address: WestendStub.address)
        fixture.presenter.presentFilter()
        fixture.presenter.presentSearch()

        XCTAssertEqual(fixture.wireframe.validatorInfoChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.filterAssetId, fixture.chainAsset.asset.id)
        XCTAssertEqual(fixture.wireframe.searchWalletId, fixture.wallet.metaId)
    }

    func testDeselectAll_thenWarningActionPerformsDeselect() {
        let fixture = makeFixture()

        fixture.presenter.deselectAll()
        fixture.wireframe.deselectAction?()

        XCTAssertTrue(fixture.wireframe.didPresentDeselectWarning)
        XCTAssertTrue(fixture.state.didPerformDeselect)
    }

    func testStateRoutes_thenShowSelectedListAndConfirmation() {
        let fixture = makeFixture()

        fixture.presenter.showSelectedList()
        fixture.presenter.showConfirmation()

        XCTAssertEqual(fixture.wireframe.selectedListChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.confirmChainAssetId, fixture.chainAsset.identifier)
    }

    func testBlockedValidatorError_thenPresentsWarningMessage() {
        let fixture = makeFixture()

        fixture.presenter.didReceiveError(error: .validatorBlocked)

        XCTAssertNotNil(fixture.wireframe.presentedMessage)
    }

    func testFilterDelegateUpdate_thenUpdatesStateAndReloads() {
        let fixture = makeFixture()
        let flow = ValidatorListFilterFlow.relaychain(filter: .defaultFilter())

        fixture.presenter.didUpdate(with: flow)

        XCTAssertTrue(fixture.state.didUpdateFilter)
        XCTAssertNotNil(fixture.view.viewModel)
    }

    private func makeFixture() -> CustomValidatorListFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let state = CustomValidatorListViewModelStateSpy()
        let viewModelFactory = CustomValidatorListViewModelFactorySpy()
        let wireframe = CustomValidatorListWireframeSpy()
        let presenter = CustomValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            viewModelState: state,
            localizationManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            wallet: wallet
        )
        let view = CustomValidatorListViewSpy()
        presenter.view = view

        return CustomValidatorListFixture(
            presenter: presenter,
            wireframe: wireframe,
            view: view,
            state: state,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            wallet: wallet
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
}

private struct CustomValidatorListFixture {
    let presenter: CustomValidatorListPresenter
    let wireframe: CustomValidatorListWireframeSpy
    let view: CustomValidatorListViewSpy
    let state: CustomValidatorListViewModelStateSpy
    let viewModelFactory: CustomValidatorListViewModelFactorySpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class CustomValidatorListViewSpy: CustomValidatorListViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var viewModel: CustomValidatorListViewModel?
    private(set) var reloadIndexes: [Int]?
    private(set) var filterAppliedState = false

    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]?) {
        self.viewModel = viewModel
        reloadIndexes = indexes
    }

    func setFilterAppliedState(to state: Bool) {
        filterAppliedState = state
    }

    func applyLocalization() {}
}

private final class CustomValidatorListViewModelStateSpy:
    CustomValidatorListViewModelState,
    ValidatorSearchRelaychainDelegate {
    weak var stateListener: CustomValidatorListModelStateListener?
    var filterApplied = true
    private(set) var updatedViewModel: CustomValidatorListViewModel?
    private(set) var didFillWithRecommended = false
    private(set) var didPerformDeselect = false
    private(set) var didChangeIdentityFilter = false
    private(set) var didChangeMinBondFilter = false
    private(set) var didClearFilter = false
    private(set) var selectedAddress: AccountAddress?
    private(set) var removedValidator: SelectedValidatorInfo?
    private(set) var removedAddress: AccountAddress?
    private(set) var didProceed = false
    private(set) var didUpdateFilter = false

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateViewModel(_ viewModel: CustomValidatorListViewModel) {
        updatedViewModel = viewModel
    }

    func validatorInfoFlow(address: String) -> ValidatorInfoFlow? {
        .relaychain(validatorInfo: nil, address: address)
    }

    func validatorSearchFlow() -> ValidatorSearchFlow? {
        .relaychain(
            validatorList: [],
            selectedValidatorList: [],
            delegate: self
        )
    }

    func validatorListFilterFlow() -> ValidatorListFilterFlow? {
        .relaychain(filter: .recommendedFilter())
    }

    func selectedValidatorListFlow() -> SelectedValidatorListFlow? {
        .relaychainExisting(
            validatorList: [],
            maxTargets: 16,
            state: makeCustomValidatorExistingBonding()
        )
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        .relaychainExisting(
            targets: [],
            maxTargets: 16,
            bonding: makeCustomValidatorExistingBonding()
        )
    }

    func remove(validator: SelectedValidatorInfo) {
        removedValidator = validator
    }

    func remove(validatorAddress: AccountAddress) {
        removedAddress = validatorAddress
    }

    func fillWithRecommended() {
        didFillWithRecommended = true
    }

    func performDeselect() {
        didPerformDeselect = true
    }

    func changeIdentityFilterValue() {
        didChangeIdentityFilter = true
    }

    func changeMinBondFilterValue() {
        didChangeMinBondFilter = true
    }

    func changeValidatorSelection(address: String) {
        selectedAddress = address
    }

    func updateFilter(with _: ValidatorListFilterFlow) {
        didUpdateFilter = true
    }

    func clearFilter() {
        didClearFilter = true
    }

    func proceed() {
        didProceed = true
    }

    func validatorSearchDidUpdate(selectedValidatorList _: [SelectedValidatorInfo]) {}
}

private final class CustomValidatorListViewModelFactorySpy:
    CustomValidatorListViewModelFactoryProtocol {
    private(set) var lastSearchText: String?

    func buildViewModel(
        viewModelState _: CustomValidatorListViewModelState,
        priceData _: PriceData?,
        locale _: Locale,
        searchText: String?
    ) -> CustomValidatorListViewModel? {
        lastSearchText = searchText

        return CustomValidatorListViewModel(
            headerViewModel: TitleWithSubtitleViewModel(title: "Header", subtitle: "Subtitle"),
            sections: [
                CustomValidatorListSectionViewModel(
                    title: "Validators",
                    cells: [
                        makeCustomValidatorCell(address: WestendStub.address),
                        makeCustomValidatorCell(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6")
                    ],
                    icon: UIImage()
                )
            ],
            selectedValidatorsCount: 1,
            selectedValidatorsLimit: 16,
            proceedButtonTitle: "Continue",
            title: "Custom"
        )
    }
}

private final class CustomValidatorListWireframeSpy: CustomValidatorListWireframeProtocol {
    private(set) var validatorInfoChainAssetId: String?
    private(set) var filterAssetId: String?
    private(set) var searchWalletId: String?
    private(set) var selectedListChainAssetId: String?
    private(set) var confirmChainAssetId: String?
    private(set) var presentedMessage: String?
    private(set) var didPresentDeselectWarning = false
    private(set) var deselectAction: (() -> Void)?

    func present(
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel,
        flow _: ValidatorInfoFlow,
        from _: ControllerBackedProtocol?
    ) {
        validatorInfoChainAssetId = chainAsset.identifier
    }

    func presentFilters(
        from _: ControllerBackedProtocol?,
        flow _: ValidatorListFilterFlow,
        delegate _: ValidatorListFilterDelegate?,
        asset: AssetModel
    ) {
        filterAssetId = asset.id
    }

    func presentSearch(
        from _: ControllerBackedProtocol?,
        flow _: ValidatorSearchFlow,
        chainAsset _: ChainAsset,
        wallet: MetaAccountModel
    ) {
        searchWalletId = wallet.metaId
    }

    func proceed(
        from _: ControllerBackedProtocol?,
        flow _: SelectedValidatorListFlow,
        delegate _: SelectedValidatorListDelegate,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        selectedListChainAssetId = chainAsset.identifier
    }

    func confirm(
        from _: ControllerBackedProtocol?,
        flow _: SelectValidatorsConfirmFlow,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        confirmChainAssetId = chainAsset.identifier
    }

    func presentDeselectValidatorsWarning(
        from _: ControllerBackedProtocol,
        action: @escaping () -> Void,
        locale _: Locale?
    ) {
        didPresentDeselectWarning = true
        deselectAction = action
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?
    ) {
        presentedMessage = message
    }

    func present(
        message: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedMessage = message
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private func makeCustomValidatorCell(address: AccountAddress) -> CustomValidatorCellViewModel {
    CustomValidatorCellViewModel(
        icon: nil,
        name: "validator",
        address: address,
        detailsAttributedString: nil,
        auxDetails: nil,
        shouldShowWarning: false,
        shouldShowError: false,
        isSelected: false
    )
}

private func makeCustomValidatorExistingBonding() -> ExistingBonding {
    ExistingBonding(
        stashAddress: WestendStub.address,
        controllerAccount: fearless.ChainAccountResponse(
            chainId: "westend",
            accountId: Data(repeating: 1, count: 32),
            publicKey: Data(repeating: 2, count: 32),
            name: "controller",
            cryptoType: .sr25519,
            addressPrefix: 42,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: "wallet"
        ),
        amount: 1,
        rewardDestination: .restake,
        selectedTargets: nil
    )
}
