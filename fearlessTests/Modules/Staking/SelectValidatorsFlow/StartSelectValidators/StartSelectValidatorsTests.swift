import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class SelectValidatorsStartTests: XCTestCase {
    func testSetup_thenStartsInteractorWiresStateShowsTextsAndLoading() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertEqual(fixture.view.textsViewModel?.stakingRecommendedTitle, "Recommended")
        XCTAssertTrue(fixture.view.didStartLoadingCalled)
    }

    func testModelStateChanged_whenViewModelBuilds_thenReloadsAndStopsLoading() {
        let fixture = makeFixture()

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        XCTAssertEqual(fixture.view.viewModel, fixture.viewModelFactory.viewModel)
        XCTAssertTrue(fixture.view.didStopLoadingCalled)
    }

    func testModelStateChanged_whenViewModelMissing_thenDoesNotStopLoading() {
        let fixture = makeFixture()
        fixture.viewModelFactory.viewModel = nil

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        XCTAssertNil(fixture.view.viewModel)
        XCTAssertFalse(fixture.view.didStopLoadingCalled)
    }

    func testSelectCustomValidators_whenFlowExists_thenRoutesToCustomList() {
        let fixture = makeFixture()

        fixture.presenter.selectCustomValidators()

        XCTAssertEqual(fixture.wireframe.customListChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.customListWalletId, fixture.wallet.metaId)
    }

    func testSelectCustomValidators_whenFlowMissing_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.state.customValidatorListFlow = nil

        fixture.presenter.selectCustomValidators()

        XCTAssertNil(fixture.wireframe.customListChainAssetId)
    }

    func testSelectRecommendedValidators_thenPresentsWarningBeforeRouting() {
        let fixture = makeFixture()

        fixture.presenter.selectRecommendedValidators()
        fixture.wireframe.presentedActions.first?.handler?()

        XCTAssertEqual(fixture.wireframe.presentedActions.count, 1)
        XCTAssertEqual(fixture.wireframe.recommendedListChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.recommendedListWalletId, fixture.wallet.metaId)
    }

    func testSelectRecommendedValidators_whenStateThrows_thenPresentsError() {
        let fixture = makeFixture()
        fixture.state.recommendedFlowError = SelectValidatorsStartError.emptyRecommendedValidators

        fixture.presenter.selectRecommendedValidators()
        fixture.wireframe.presentedActions.first?.handler?()

        XCTAssertNil(fixture.wireframe.recommendedListChainAssetId)
        XCTAssertNotNil(fixture.wireframe.presentedError)
    }

    func testDidReceiveError_whenWireframeCannotPresentOriginal_thenPresentsFallback() {
        let fixture = makeFixture()
        fixture.wireframe.shouldPresentError = false

        fixture.presenter.didReceiveError(error: SelectValidatorsStartError.dataNotLoaded)

        XCTAssertEqual(fixture.wireframe.presentErrorCallCount, 2)
    }

    private func makeFixture() -> SelectValidatorsStartFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = SelectValidatorsStartInteractorInputSpy()
        let wireframe = SelectValidatorsStartWireframeSpy()
        let state = SelectValidatorsStartViewModelStateSpy()
        let viewModelFactory = SelectValidatorsStartViewModelFactorySpy()
        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            wallet: wallet,
            viewModelState: state,
            viewModelFactory: viewModelFactory
        )
        let view = SelectValidatorsStartViewSpy()
        view.localizationManager = LocalizationManager.shared
        presenter.view = view

        return SelectValidatorsStartFixture(
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

private struct SelectValidatorsStartFixture {
    let presenter: SelectValidatorsStartPresenter
    let interactor: SelectValidatorsStartInteractorInputSpy
    let wireframe: SelectValidatorsStartWireframeSpy
    let view: SelectValidatorsStartViewSpy
    let state: SelectValidatorsStartViewModelStateSpy
    let viewModelFactory: SelectValidatorsStartViewModelFactorySpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class SelectValidatorsStartInteractorInputSpy: SelectValidatorsStartInteractorInputProtocol {
    private(set) var didSetup = false

    func setup() {
        didSetup = true
    }
}

private final class SelectValidatorsStartViewSpy: SelectValidatorsStartViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = false

    private(set) var viewModel: SelectValidatorsStartViewModel?
    private(set) var textsViewModel: SelectValidatorsStartTextsViewModel?
    private(set) var didStartLoadingCalled = false
    private(set) var didStopLoadingCalled = false

    func didReceive(viewModel: SelectValidatorsStartViewModel?) {
        self.viewModel = viewModel
    }

    func didReceive(textsViewModel: SelectValidatorsStartTextsViewModel) {
        self.textsViewModel = textsViewModel
    }

    func didStartLoading() {
        didStartLoadingCalled = true
    }

    func didStopLoading() {
        didStopLoadingCalled = true
    }

    func applyLocalization() {}
}

private final class SelectValidatorsStartViewModelStateSpy: SelectValidatorsStartViewModelState {
    weak var stateListener: SelectValidatorsStartModelStateListener?
    var customValidatorListFlow: CustomValidatorListFlow? = makeCustomValidatorListFlow()
    var recommendedValidatorListFlowToReturn: RecommendedValidatorListFlow? = makeRecommendedValidatorListFlow()
    var recommendedFlowError: Error?

    func setStateListener(_ stateListener: SelectValidatorsStartModelStateListener?) {
        self.stateListener = stateListener
    }

    func recommendedValidatorListFlow() throws -> RecommendedValidatorListFlow? {
        if let recommendedFlowError {
            throw recommendedFlowError
        }

        return recommendedValidatorListFlowToReturn
    }
}

private final class SelectValidatorsStartViewModelFactorySpy:
    SelectValidatorsStartViewModelFactoryProtocol {
    var viewModel: SelectValidatorsStartViewModel? = SelectValidatorsStartViewModel(
        selectedCount: 3,
        totalCount: 16,
        recommendedValidatorListLoaded: true
    )

    func buildViewModel(viewModelState _: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        viewModel
    }

    func buildTextsViewModel(locale _: Locale) -> SelectValidatorsStartTextsViewModel? {
        SelectValidatorsStartTextsViewModel(
            algoSteps: ["one", "two"],
            stakingRecommendedTitle: "Recommended",
            algoSectionLabel: "Algorithm",
            algoDetailsLabel: "Details",
            suggestedValidatorsWarningViewTitle: "Warning",
            customValidatorsSectionLabel: "Custom",
            customValidatorsDetailsLabel: "Details"
        )
    }
}

private final class SelectValidatorsStartWireframeSpy:
    SelectValidatorsStartWireframeProtocol {
    private(set) var customListChainAssetId: String?
    private(set) var customListWalletId: String?
    private(set) var recommendedListChainAssetId: String?
    private(set) var recommendedListWalletId: String?
    private(set) var presentedActions: [SheetAlertPresentableAction] = []
    private(set) var presentedError: Error?
    private(set) var presentErrorCallCount = 0
    var shouldPresentError = true

    func proceedToCustomList(
        from _: ControllerBackedProtocol?,
        flow _: CustomValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        customListChainAssetId = chainAsset.identifier
        customListWalletId = wallet.metaId
    }

    func proceedToRecommendedList(
        from _: SelectValidatorsStartViewProtocol?,
        flow _: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        recommendedListChainAssetId = chainAsset.identifier
        recommendedListWalletId = wallet.metaId
    }

    @discardableResult
    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        presentErrorCallCount += 1
        return shouldPresentError
    }

    func present(viewModel _: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions: [SheetAlertPresentableAction]
    ) {
        presentedActions = actions
    }

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
}

private func makeCustomValidatorListFlow() -> CustomValidatorListFlow {
    .relaychainExisting(
        validatorList: [],
        recommendedValidatorList: [],
        selectedValidatorList: SharedList<SelectedValidatorInfo>(items: []),
        maxTargets: 16,
        bonding: makeExistingBonding()
    )
}

private func makeRecommendedValidatorListFlow() -> RecommendedValidatorListFlow {
    .relaychainExisting(
        validators: [],
        maxTargets: 16,
        bonding: makeExistingBonding()
    )
}

private func makeExistingBonding() -> ExistingBonding {
    ExistingBonding(
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
}
