import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class ValidatorSearchTests: XCTestCase {
    func testSetup_whenSearchEmpty_thenResetsView() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertTrue(fixture.state.didReset)
        XCTAssertTrue(fixture.view.didResetCalled)
    }

    func testSearchText_thenPerformsSearchAndReloadsWhenStateChanges() {
        let fixture = makeFixture()

        fixture.presenter.search(for: "alice")
        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        XCTAssertEqual(fixture.state.searchString, "alice")
        XCTAssertTrue(fixture.state.didPerformSearch)
        XCTAssertEqual(fixture.view.viewModel?.cellViewModels.count, 2)
        XCTAssertEqual(fixture.state.updatedViewModel?.cellViewModels.count, 2)
    }

    func testSearchAddress_thenPerformsFullAddressSearch() {
        let fixture = makeFixture()

        fixture.presenter.search(for: WestendStub.address)

        XCTAssertEqual(fixture.state.fullAddressSearchAddress, WestendStub.address)
        XCTAssertEqual(fixture.state.fullAddressSearchAccountId?.count, 32)
        XCTAssertFalse(fixture.state.didPerformSearch)
    }

    func testSearchWhilePreviousSearchActive_thenStopsPreviousSearch() {
        let fixture = makeFixture()

        fixture.presenter.search(for: "alice")
        fixture.presenter.search(for: "bob")

        XCTAssertTrue(fixture.view.didStopSearchCalled)
        XCTAssertEqual(fixture.state.searchString, "bob")
    }

    func testLoadingAndErrorCallbacks_thenForwardToViewAndResetState() {
        let fixture = makeFixture()

        fixture.presenter.didStartLoading()
        fixture.presenter.didStopLoading()
        fixture.presenter.didReceiveError(error: ValidatorSearchError.validatorBlocked)

        XCTAssertTrue(fixture.view.didStartSearchCalled)
        XCTAssertTrue(fixture.view.didStopSearchCalled)
        XCTAssertTrue(fixture.view.didResetCalled)
        XCTAssertTrue(fixture.state.didUpdateViewModelWithNil)
    }

    func testDidNotFoundLocalValidator_thenStartsRemoteSearch() {
        let fixture = makeFixture()
        let accountId = Data(repeating: 7, count: 32)

        fixture.presenter.didNotFoundLocalValidator(accountId: accountId)

        XCTAssertTrue(fixture.view.didStartSearchCalled)
        XCTAssertEqual(fixture.interactor.accountId, accountId)
    }

    func testDidSelectValidator_whenFlowExists_thenRoutesToValidatorInfo() {
        let fixture = makeFixture()

        fixture.presenter.didSelectValidator(at: 0)

        XCTAssertEqual(fixture.wireframe.validatorInfoChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.validatorInfoWalletId, fixture.wallet.metaId)
    }

    func testApplyChanges_thenAppliesStateAndCloses() {
        let fixture = makeFixture()

        fixture.presenter.applyChanges()

        XCTAssertTrue(fixture.state.didApplyChanges)
        XCTAssertTrue(fixture.wireframe.didClose)
    }

    private func makeFixture() -> ValidatorSearchFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let wireframe = ValidatorSearchWireframeSpy()
        let interactor = ValidatorSearchInteractorInputSpy()
        let state = ValidatorSearchViewModelStateSpy()
        let viewModelFactory = ValidatorSearchViewModelFactorySpy()
        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            viewModelState: state,
            localizationManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            wallet: wallet
        )
        let view = ValidatorSearchViewSpy()
        presenter.view = view

        return ValidatorSearchFixture(
            presenter: presenter,
            wireframe: wireframe,
            interactor: interactor,
            view: view,
            state: state,
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

private struct ValidatorSearchFixture {
    let presenter: ValidatorSearchPresenter
    let wireframe: ValidatorSearchWireframeSpy
    let interactor: ValidatorSearchInteractorInputSpy
    let view: ValidatorSearchViewSpy
    let state: ValidatorSearchViewModelStateSpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class ValidatorSearchInteractorInputSpy: ValidatorSearchInteractorInputProtocol {
    private(set) var accountId: AccountId?

    func performValidatorSearch(accountId: AccountId) {
        self.accountId = accountId
    }
}

private final class ValidatorSearchViewSpy: ValidatorSearchViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var viewModel: ValidatorSearchViewModel?
    private(set) var didStartSearchCalled = false
    private(set) var didStopSearchCalled = false
    private(set) var didResetCalled = false

    func didReload(_ viewModel: ValidatorSearchViewModel) {
        self.viewModel = viewModel
    }

    func didStartSearch() {
        didStartSearchCalled = true
    }

    func didStopSearch() {
        didStopSearchCalled = true
    }

    func didReset() {
        didResetCalled = true
    }

    func applyLocalization() {}
}

private final class ValidatorSearchViewModelStateSpy: ValidatorSearchViewModelState {
    weak var stateListener: ValidatorSearchModelStateListener?
    var searchString = ""
    private(set) var updatedViewModel: ValidatorSearchViewModel?
    private(set) var didUpdateViewModelWithNil = false
    private(set) var didReset = false
    private(set) var fullAddressSearchAddress: AccountAddress?
    private(set) var fullAddressSearchAccountId: AccountId?
    private(set) var didPerformSearch = false
    private(set) var selectedIndex: Int?
    private(set) var didApplyChanges = false
    var validatorInfoFlowToReturn: ValidatorInfoFlow? = .relaychain(
        validatorInfo: nil,
        address: WestendStub.address
    )

    func setStateListener(_ stateListener: ValidatorSearchModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateViewModel(_ viewModel: ValidatorSearchViewModel?) {
        updatedViewModel = viewModel
        didUpdateViewModelWithNil = viewModel == nil
    }

    func validatorInfoFlow(index _: Int) -> ValidatorInfoFlow? {
        validatorInfoFlowToReturn
    }

    func reset() {
        didReset = true
    }

    func performFullAddressSearch(by address: AccountAddress, accountId: AccountId) {
        fullAddressSearchAddress = address
        fullAddressSearchAccountId = accountId
    }

    func performSearch() {
        didPerformSearch = true
    }

    func changeValidatorSelection(at index: Int) {
        selectedIndex = index
    }

    func applyChanges() {
        didApplyChanges = true
    }
}

private final class ValidatorSearchViewModelFactorySpy: ValidatorSearchViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState _: ValidatorSearchViewModelState,
        locale _: Locale
    ) -> ValidatorSearchViewModel? {
        ValidatorSearchViewModel(
            headerViewModel: TitleWithSubtitleViewModel(title: "Results"),
            cellViewModels: [
                makeValidatorSearchCell(address: WestendStub.address),
                makeValidatorSearchCell(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6")
            ],
            differsFromInitial: true
        )
    }
}

private final class ValidatorSearchWireframeSpy: ValidatorSearchWireframeProtocol {
    private(set) var validatorInfoChainAssetId: String?
    private(set) var validatorInfoWalletId: String?
    private(set) var didClose = false

    func present(
        flow _: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        validatorInfoChainAssetId = chainAsset.identifier
        validatorInfoWalletId = wallet.metaId
    }

    func close(_: ControllerBackedProtocol?) {
        didClose = true
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

private func makeValidatorSearchCell(address: AccountAddress) -> ValidatorSearchCellViewModel {
    ValidatorSearchCellViewModel(
        icon: nil,
        name: "validator",
        address: address,
        detailsAttributedString: nil,
        detailsAux: nil,
        shouldShowWarning: false,
        shouldShowError: false,
        isSelected: false
    )
}
