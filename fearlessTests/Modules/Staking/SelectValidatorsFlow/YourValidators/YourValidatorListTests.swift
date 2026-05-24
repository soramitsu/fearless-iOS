import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class YourValidatorListTests: XCTestCase {
    func testDidLoad_thenSetsListenerAndStartsInteractor() {
        let fixture = makeFixture()

        fixture.presenter.didLoad(view: fixture.view)

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
    }

    func testWillAppear_whenViewNotLoaded_thenStartsLoading() {
        let fixture = makeFixture()

        fixture.presenter.willAppear(view: fixture.view)

        XCTAssertTrue(fixture.view.didStartLoadingCalled)
    }

    func testModelStateChanged_whenViewModelBuilds_thenStopsLoadingAndReloadsList() {
        let fixture = makeFixture()

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        guard case let .validatorList(viewModel)? = fixture.view.lastState else {
            XCTFail("Expected validator list state")
            return
        }

        XCTAssertTrue(fixture.view.didStopLoadingCalled)
        XCTAssertEqual(viewModel.sections.first?.validators.first?.address, WestendStub.address)
        XCTAssertTrue(fixture.viewModelFactory.didBuildViewModel)
    }

    func testModelStateChanged_whenViewModelMissing_thenReloadsError() {
        let fixture = makeFixture()
        fixture.viewModelFactory.viewModel = nil

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        guard case let .error(message)? = fixture.view.lastState else {
            XCTFail("Expected error state")
            return
        }

        XCTAssertFalse(message.isEmpty)
    }

    func testRetry_thenResetsStateAndRefreshesInteractor() {
        let fixture = makeFixture()

        fixture.presenter.retry()

        XCTAssertTrue(fixture.state.didResetState)
        XCTAssertTrue(fixture.interactor.didRefresh)
    }

    func testDidSelectValidator_whenFlowExists_thenRoutesToValidatorInfo() {
        let fixture = makeFixture()
        let viewModel = makeValidatorViewModel(address: WestendStub.address)

        fixture.presenter.didSelectValidator(viewModel: viewModel)

        XCTAssertEqual(fixture.wireframe.validatorInfoChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.validatorInfoWalletId, fixture.wallet.metaId)
    }

    func testDidSelectValidator_whenFlowMissing_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.state.validatorInfoFlowToReturn = nil

        fixture.presenter.didSelectValidator(viewModel: makeValidatorViewModel(address: WestendStub.address))

        XCTAssertNil(fixture.wireframe.validatorInfoChainAssetId)
    }

    func testChangeValidators_whenFlowExists_thenRoutesToSelectValidatorsStart() {
        let fixture = makeFixture()

        fixture.presenter.changeValidators()

        XCTAssertEqual(fixture.wireframe.selectValidatorsChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.selectValidatorsWalletId, fixture.wallet.metaId)
    }

    func testMissingControllerCallback_thenPresentsMissingControllerWarning() {
        let fixture = makeFixture()

        fixture.presenter.handleControllerAccountMissing(WestendStub.address)

        XCTAssertEqual(fixture.wireframe.missingControllerAddress, WestendStub.address)
    }

    func testDidReceiveState_thenReloadsStateDirectly() {
        let fixture = makeFixture()

        fixture.presenter.didReceiveState(.loading)

        guard case .loading? = fixture.view.lastState else {
            XCTFail("Expected loading state")
            return
        }
    }

    private func makeFixture() -> YourValidatorListFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let state = YourValidatorListViewModelStateSpy()
        let viewModelFactory = YourValidatorListViewModelFactorySpy()
        let interactor = YourValidatorListInteractorInputSpy()
        let wireframe = YourValidatorListWireframeSpy()
        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            localizationManager: LocalizationManager.shared,
            logger: YourValidatorListLoggerSpy(),
            viewModelState: state
        )
        let view = YourValidatorListViewSpy()
        presenter.view = view

        return YourValidatorListFixture(
            presenter: presenter,
            interactor: interactor,
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

private struct YourValidatorListFixture {
    let presenter: YourValidatorListPresenter
    let interactor: YourValidatorListInteractorInputSpy
    let wireframe: YourValidatorListWireframeSpy
    let view: YourValidatorListViewSpy
    let state: YourValidatorListViewModelStateSpy
    let viewModelFactory: YourValidatorListViewModelFactorySpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class YourValidatorListViewSpy: YourValidatorListViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var lastState: YourValidatorListViewState?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func reload(state: YourValidatorListViewState) {
        lastState = state
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class YourValidatorListInteractorInputSpy: YourValidatorListInteractorInputProtocol {
    private(set) var didSetup = false
    private(set) var didRefresh = false

    func setup() {
        didSetup = true
    }

    func refresh() {
        didRefresh = true
    }
}

private final class YourValidatorListViewModelStateSpy: YourValidatorListViewModelState {
    weak var stateListener: YourValidatorListModelStateListener?
    private(set) var didResetState = false
    private(set) var locale: Locale?
    var validatorInfoFlowToReturn: ValidatorInfoFlow? = .relaychain(validatorInfo: nil, address: WestendStub.address)
    var selectValidatorsStartFlowToReturn: SelectValidatorsStartFlow? = .relaychainExisting(
        state: ExistingBonding(
            stashAddress: WestendStub.address,
            controllerAccount: ChainAccountResponse(
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
    )

    func setStateListener(_ stateListener: YourValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func selectValidatorsStartFlow() -> SelectValidatorsStartFlow? {
        selectValidatorsStartFlowToReturn
    }

    func validatorInfoFlow(address _: String) -> ValidatorInfoFlow? {
        validatorInfoFlowToReturn
    }

    func resetState() {
        didResetState = true
    }

    func changeLocale(_ locale: Locale) {
        self.locale = locale
    }
}

private final class YourValidatorListViewModelFactorySpy: YourValidatorListViewModelFactoryProtocol {
    private(set) var lastState: YourValidatorListViewModelState?
    private(set) var didBuildViewModel = false
    var viewModel: YourValidatorListViewModel? = YourValidatorListViewModel(
        allValidatorWithoutRewards: false,
        sections: [
            YourValidatorListSection(
                status: .stakeAllocated,
                validators: [makeValidatorViewModel(address: WestendStub.address)]
            )
        ],
        userCanSelectValidators: true
    )

    func buildViewModel(
        viewModelState: YourValidatorListViewModelState,
        locale _: Locale
    ) -> YourValidatorListViewModel? {
        lastState = viewModelState
        didBuildViewModel = true
        return viewModel
    }
}

private final class YourValidatorListWireframeSpy: YourValidatorListWireframeProtocol {
    private(set) var validatorInfoChainAssetId: String?
    private(set) var validatorInfoWalletId: String?
    private(set) var selectValidatorsChainAssetId: String?
    private(set) var selectValidatorsWalletId: String?
    private(set) var missingControllerAddress: String?
    private(set) var presentedError: Error?

    func present(
        flow _: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from _: YourValidatorListViewProtocol?
    ) {
        validatorInfoChainAssetId = chainAsset.identifier
        validatorInfoWalletId = wallet.metaId
    }

    func proceedToSelectValidatorsStart(
        from _: YourValidatorListViewProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow _: SelectValidatorsStartFlow
    ) {
        selectValidatorsChainAssetId = chainAsset.identifier
        selectValidatorsWalletId = wallet.metaId
    }

    func presentMissingController(
        from _: ControllerBackedProtocol,
        address: AccountAddress,
        locale _: Locale?
    ) {
        missingControllerAddress = address
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
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

private func makeValidatorViewModel(address: AccountAddress) -> YourValidatorViewModel {
    YourValidatorViewModel(
        address: address,
        name: "validator",
        amount: "1 UNIT",
        apy: nil,
        staked: "1 UNIT",
        shouldHaveWarning: false,
        shouldHaveError: false
    )
}

private final class YourValidatorListLoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}
