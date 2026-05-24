import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class SelectedValidatorListTests: XCTestCase {
    func testSetup_thenWiresStateAndReloadsViewModel() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertEqual(fixture.view.viewModel?.cellViewModels.count, 2)
    }

    func testModelStateChanged_thenReloadsViewModel() {
        let fixture = makeFixture()

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        XCTAssertEqual(fixture.view.viewModel?.headerViewModel.title, "Selected")
    }

    func testValidatorRemoved_thenSendsAnimatedRemovalViewModel() {
        let fixture = makeFixture()

        fixture.presenter.validatorRemovedAtIndex(1, viewModelState: fixture.state)

        XCTAssertEqual(fixture.view.changedIndex, 1)
        XCTAssertEqual(fixture.view.changedViewModel?.cellViewModels.count, 2)
    }

    func testRemoveItem_thenForwardsToState() {
        let fixture = makeFixture()

        fixture.presenter.removeItem(at: 1)

        XCTAssertEqual(fixture.state.removedIndex, 1)
    }

    func testDidSelectValidator_whenFlowExists_thenRoutesToValidatorInfo() {
        let fixture = makeFixture()

        fixture.presenter.didSelectValidator(at: 0)

        XCTAssertEqual(fixture.wireframe.validatorInfoChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.validatorInfoWalletId, fixture.wallet.metaId)
    }

    func testDidSelectValidator_whenFlowMissing_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.state.validatorInfoFlowToReturn = nil

        fixture.presenter.didSelectValidator(at: 0)

        XCTAssertNil(fixture.wireframe.validatorInfoChainAssetId)
    }

    func testProceed_whenFlowExists_thenRoutesToConfirmation() {
        let fixture = makeFixture()

        fixture.presenter.proceed()

        XCTAssertEqual(fixture.wireframe.confirmChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.confirmWalletId, fixture.wallet.metaId)
    }

    func testDismiss_thenDismissesView() {
        let fixture = makeFixture()

        fixture.presenter.dismiss()

        XCTAssertTrue(fixture.wireframe.didDismiss)
    }

    private func makeFixture() -> SelectedValidatorListFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let wireframe = SelectedValidatorListWireframeSpy()
        let state = SelectedValidatorListViewModelStateSpy()
        let viewModelFactory = SelectedValidatorListViewModelFactorySpy()
        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            viewModelState: state,
            localizationManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            wallet: wallet
        )
        let view = SelectedValidatorListViewSpy()
        presenter.view = view

        return SelectedValidatorListFixture(
            presenter: presenter,
            wireframe: wireframe,
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

private struct SelectedValidatorListFixture {
    let presenter: SelectedValidatorListPresenter
    let wireframe: SelectedValidatorListWireframeSpy
    let view: SelectedValidatorListViewSpy
    let state: SelectedValidatorListViewModelStateSpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class SelectedValidatorListViewSpy: SelectedValidatorListViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var viewModel: SelectedValidatorListViewModel?
    private(set) var changedViewModel: SelectedValidatorListViewModel?
    private(set) var changedIndex: Int?

    func didReload(_ viewModel: SelectedValidatorListViewModel) {
        self.viewModel = viewModel
    }

    func didChangeViewModel(
        _ viewModel: SelectedValidatorListViewModel,
        byRemovingItemAt index: Int
    ) {
        changedViewModel = viewModel
        changedIndex = index
    }

    func applyLocalization() {}
}

private final class SelectedValidatorListViewModelStateSpy:
    SelectedValidatorListViewModelState {
    weak var stateListener: SelectedValidatorListModelStateListener?
    weak var delegate: SelectedValidatorListDelegate?
    private(set) var removedIndex: Int?
    var validatorInfoFlowToReturn: ValidatorInfoFlow? = .relaychain(
        validatorInfo: nil,
        address: WestendStub.address
    )
    var confirmFlowToReturn: SelectValidatorsConfirmFlow? = .relaychainExisting(
        targets: [],
        maxTargets: 16,
        bonding: makeSelectedValidatorExistingBonding()
    )

    func setStateListener(_ stateListener: SelectedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(validatorIndex _: Int) -> ValidatorInfoFlow? {
        validatorInfoFlowToReturn
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        confirmFlowToReturn
    }

    func removeItem(at index: Int) {
        removedIndex = index
    }
}

private final class SelectedValidatorListViewModelFactorySpy:
    SelectedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState _: SelectedValidatorListViewModelState,
        locale _: Locale
    ) -> SelectedValidatorListViewModel? {
        SelectedValidatorListViewModel(
            headerViewModel: TitleWithSubtitleViewModel(title: "Selected"),
            cellViewModels: [
                makeSelectedValidatorCell(address: WestendStub.address),
                makeSelectedValidatorCell(address: "5EJQtTE1ZS9cBdqiuUdjQtieNLRVjk7Pyo6Bfv8Ff6e7pnr6")
            ],
            limitIsExceeded: false,
            selectedValidatorsLimit: 16
        )
    }
}

private final class SelectedValidatorListWireframeSpy: SelectedValidatorListWireframeProtocol {
    private(set) var validatorInfoChainAssetId: String?
    private(set) var validatorInfoWalletId: String?
    private(set) var confirmChainAssetId: String?
    private(set) var confirmWalletId: String?
    private(set) var didDismiss = false

    func present(
        flow _: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        validatorInfoChainAssetId = chainAsset.identifier
        validatorInfoWalletId = wallet.metaId
    }

    func proceed(
        from _: SelectedValidatorListViewProtocol?,
        flow _: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        confirmChainAssetId = chainAsset.identifier
        confirmWalletId = wallet.metaId
    }

    func dismiss(_: ControllerBackedProtocol?) {
        didDismiss = true
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

private func makeSelectedValidatorCell(address: AccountAddress) -> SelectedValidatorCellViewModel {
    SelectedValidatorCellViewModel(
        icon: nil,
        name: "validator",
        address: address,
        detailsAttributedString: nil,
        detailsAux: nil,
        shouldShowWarning: false,
        shouldShowError: false
    )
}

private func makeSelectedValidatorExistingBonding() -> ExistingBonding {
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
