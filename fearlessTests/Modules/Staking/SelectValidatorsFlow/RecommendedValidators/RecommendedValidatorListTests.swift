import FearlessFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class RecommendedValidatorListTests: XCTestCase {
    func testSetup_thenWiresStateAndReloadsViewModel() {
        let fixture = makeFixture()

        fixture.presenter.setup()

        XCTAssertTrue(fixture.state.stateListener === fixture.presenter)
        XCTAssertEqual(fixture.view.viewModel?.itemViewModels.count, 2)
        XCTAssertEqual(fixture.view.viewModel?.title, "Recommended")
    }

    func testModelStateChanged_thenReloadsViewModel() {
        let fixture = makeFixture()

        fixture.presenter.modelStateDidChanged(viewModelState: fixture.state)

        XCTAssertEqual(fixture.view.viewModel?.continueButtonTitle, "Continue")
    }

    func testShowValidatorInfo_whenFlowExists_thenRoutesToInfo() {
        let fixture = makeFixture()

        fixture.presenter.showValidatorInfoAt(index: 0)

        XCTAssertEqual(fixture.wireframe.validatorInfoChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.validatorInfoWalletId, fixture.wallet.metaId)
    }

    func testShowValidatorInfo_whenFlowMissing_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.state.validatorInfoFlowToReturn = nil

        fixture.presenter.showValidatorInfoAt(index: 0)

        XCTAssertNil(fixture.wireframe.validatorInfoChainAssetId)
    }

    func testSelectedValidatorAt_thenAsksStateWhetherSelectionIsAllowed() {
        let fixture = makeFixture()

        fixture.presenter.selectedValidatorAt(index: 1)

        XCTAssertEqual(fixture.state.shouldSelectIndex, 1)
    }

    func testProceed_whenFlowExists_thenRoutesToConfirmation() {
        let fixture = makeFixture()

        fixture.presenter.proceed()

        XCTAssertEqual(fixture.wireframe.confirmChainAssetId, fixture.chainAsset.identifier)
        XCTAssertEqual(fixture.wireframe.confirmWalletId, fixture.wallet.metaId)
    }

    func testProceed_whenFlowMissing_thenDoesNotRoute() {
        let fixture = makeFixture()
        fixture.state.confirmFlowToReturn = nil

        fixture.presenter.proceed()

        XCTAssertNil(fixture.wireframe.confirmChainAssetId)
    }

    private func makeFixture() -> RecommendedValidatorListFixture {
        let chainAsset = makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let state = RecommendedValidatorListViewModelStateSpy()
        let viewModelFactory = RecommendedValidatorListViewModelFactorySpy()
        let presenter = RecommendedValidatorListPresenter(
            viewModelFactory: viewModelFactory,
            viewModelState: state,
            chainAsset: chainAsset,
            wallet: wallet
        )
        let view = RecommendedValidatorListViewSpy()
        let wireframe = RecommendedValidatorListWireframeSpy()
        presenter.view = view
        presenter.wireframe = wireframe

        return RecommendedValidatorListFixture(
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

private struct RecommendedValidatorListFixture {
    let presenter: RecommendedValidatorListPresenter
    let wireframe: RecommendedValidatorListWireframeSpy
    let view: RecommendedValidatorListViewSpy
    let state: RecommendedValidatorListViewModelStateSpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class RecommendedValidatorListViewSpy: RecommendedValidatorListViewProtocol {
    let controller = UIViewController()
    let isSetup = true
    private(set) var viewModel: RecommendedValidatorListViewModelProtocol?

    func didReceive(viewModel: RecommendedValidatorListViewModelProtocol) {
        self.viewModel = viewModel
    }

    func applyLocalization() {}
}

private final class RecommendedValidatorListViewModelStateSpy:
    RecommendedValidatorListViewModelState {
    weak var stateListener: RecommendedValidatorListModelStateListener?
    private(set) var shouldSelectIndex: Int?
    var validatorInfoFlowToReturn: ValidatorInfoFlow? = .relaychain(
        validatorInfo: nil,
        address: WestendStub.address
    )
    var confirmFlowToReturn: SelectValidatorsConfirmFlow? = .relaychainExisting(
        targets: [],
        maxTargets: 16,
        bonding: makeRecommendedValidatorExistingBonding()
    )

    func setStateListener(_ stateListener: RecommendedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(validatorIndex _: Int) -> ValidatorInfoFlow? {
        validatorInfoFlowToReturn
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        confirmFlowToReturn
    }

    func shouldSelectValidatorAt(index: Int) -> Bool {
        shouldSelectIndex = index
        return true
    }
}

private final class RecommendedValidatorListViewModelFactorySpy:
    RecommendedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState _: RecommendedValidatorListViewModelState,
        locale _: Locale
    ) -> RecommendedValidatorListViewModel? {
        RecommendedValidatorListViewModel(
            itemsCountString: LocalizableResource { _ in "2 validators" },
            itemViewModels: [
                LocalizableResource { _ in makeRecommendedValidatorViewModel(title: "validator 1") },
                LocalizableResource { _ in makeRecommendedValidatorViewModel(title: "validator 2") }
            ],
            title: "Recommended",
            continueButtonEnabled: true,
            rewardColumnTitle: "Reward",
            continueButtonTitle: "Continue"
        )
    }
}

private final class RecommendedValidatorListWireframeSpy:
    RecommendedValidatorListWireframeProtocol {
    private(set) var validatorInfoChainAssetId: String?
    private(set) var validatorInfoWalletId: String?
    private(set) var confirmChainAssetId: String?
    private(set) var confirmWalletId: String?

    func present(
        flow _: ValidatorInfoFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from _: RecommendedValidatorListViewProtocol?
    ) {
        validatorInfoChainAssetId = chainAsset.identifier
        validatorInfoWalletId = wallet.metaId
    }

    func proceed(
        from _: RecommendedValidatorListViewProtocol?,
        flow _: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        confirmChainAssetId = chainAsset.identifier
        confirmWalletId = wallet.metaId
    }
}

private func makeRecommendedValidatorViewModel(title: String) -> RecommendedValidatorViewModel {
    RecommendedValidatorViewModel(
        icon: nil,
        title: title,
        detailsAttributedString: nil,
        detailsAux: nil,
        isSelected: false
    )
}

private func makeRecommendedValidatorExistingBonding() -> ExistingBonding {
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
