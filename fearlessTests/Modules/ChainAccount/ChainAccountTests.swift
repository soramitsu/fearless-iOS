import XCTest
import UIKit
import BigInt
import FearlessFoundation
import SSFModels
@testable import fearless

final class ChainAccountTests: XCTestCase {
    func testSetup_whenCalled_thenStartsInteractorAndDeliversInitialViewModel() {
        let fixture = makeFixture()
        let expectation = expectation(description: "view model delivered")
        var didFulfill = false
        fixture.view.onDidReceiveState = { state in
            guard case .loaded = state, !didFulfill else {
                return
            }
            didFulfill = true
            expectation.fulfill()
        }

        fixture.presenter.setup()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(fixture.interactor.didSetup)
        XCTAssertEqual(fixture.view.loadedViewModel?.walletName, fixture.wallet.name)
        XCTAssertEqual(fixture.view.loadedViewModel?.selectedChainName, fixture.chainAsset.chain.name)
        XCTAssertEqual(fixture.factory.receivedMode, .simple)
    }

    func testPrimaryActions_whenTapped_thenRouteWithCurrentWalletAndChainAsset() {
        let fixture = makeFixture()

        fixture.presenter.didTapSendButton()
        fixture.presenter.didTapReceiveButton()
        fixture.presenter.didTapCrossChainButton()
        fixture.presenter.didTapPolkaswapButton()
        fixture.presenter.didTapLockedInfoButton()
        fixture.presenter.didTapBackButton()
        fixture.presenter.didPullToRefresh()

        XCTAssertEqual(fixture.wireframe.sendChainAsset?.chain.chainId, fixture.chainAsset.chain.chainId)
        XCTAssertEqual(fixture.wireframe.sendWallet?.metaId, fixture.wallet.metaId)
        XCTAssertEqual(fixture.wireframe.receiveAsset?.id, fixture.chainAsset.asset.id)
        XCTAssertEqual(fixture.wireframe.crossChainAsset?.chain.chainId, fixture.chainAsset.chain.chainId)
        XCTAssertEqual(fixture.wireframe.polkaswapChainAsset?.chain.chainId, fixture.chainAsset.chain.chainId)
        XCTAssertEqual(fixture.wireframe.lockedInfoChainAsset?.chain.chainId, fixture.chainAsset.chain.chainId)
        XCTAssertTrue(fixture.wireframe.closedView === fixture.view)
        XCTAssertTrue(fixture.interactor.didUpdateData)
    }

    func testExportOptions_whenReceived_thenBuildsActionMenuAndRoutesSelections() throws {
        let fixture = makeFixture()
        fixture.interactor.isClaimAvailable = true

        fixture.presenter.didTapOptionsButton()
        fixture.presenter.didReceiveExportOptions(options: [.mnemonic, .seed])

        XCTAssertNotNil(fixture.interactor.exportAddress)
        XCTAssertEqual(
            fixture.wireframe.chainActionItems.map(\.testCaseName),
            ["export", "switchNode", "replace", "claimCrowdloanRewards"]
        )

        try XCTUnwrap(fixture.wireframe.chainActionCallback)(0)
        XCTAssertEqual(fixture.wireframe.exportOptions, [.mnemonic, .seed])
        XCTAssertEqual(fixture.wireframe.exportWallet?.metaId, fixture.wallet.metaId)

        try XCTUnwrap(fixture.wireframe.chainActionCallback)(1)
        XCTAssertEqual(fixture.wireframe.nodeSelectionChain?.chainId, fixture.chainAsset.chain.chainId)

        try XCTUnwrap(fixture.wireframe.chainActionCallback)(3)
        XCTAssertEqual(fixture.wireframe.claimChainAsset?.chain.chainId, fixture.chainAsset.chain.chainId)
    }

    func testDidUpdateChainAsset_whenExtendedMode_thenRefreshesBalanceInfoAndTransactionHistory() {
        let fixture = makeFixture(mode: .extended)
        let updatedChainAsset = Self.makeChainAsset()

        fixture.presenter.didUpdate(chainAsset: updatedChainAsset)

        guard case let .chainAsset(wallet, chainAsset)? = fixture.balanceInfoModule.infoType else {
            return XCTFail("Expected chain asset balance info replacement")
        }

        XCTAssertEqual(wallet.metaId, fixture.wallet.metaId)
        XCTAssertEqual(chainAsset.chain.chainId, updatedChainAsset.chain.chainId)
        XCTAssertEqual(fixture.moduleOutput.updatedChainAsset?.chain.chainId, updatedChainAsset.chain.chainId)
    }

    func testChainSelection_whenModeChanges_thenRoutesForSimpleAndUpdatesForExtended() {
        let selectedChain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let simpleFixture = makeFixture(mode: .simple)
        let extendedFixture = makeFixture(mode: .extended)

        simpleFixture.presenter.chainSelection(
            view: SelectNetworkViewInputStub(),
            didCompleteWith: selectedChain,
            contextTag: nil
        )
        extendedFixture.presenter.chainSelection(
            view: SelectNetworkViewInputStub(),
            didCompleteWith: selectedChain,
            contextTag: nil
        )

        XCTAssertEqual(simpleFixture.wireframe.detailsChainAsset?.chain.chainId, selectedChain.chainId)
        XCTAssertEqual(extendedFixture.interactor.updatedChain?.chainId, selectedChain.chainId)
    }

    private func makeFixture(mode: ChainAccountViewMode = .simple) -> ChainAccountFixture {
        let chainAsset = Self.makeChainAsset()
        let wallet = AccountGenerator.generateMetaAccount()
        let interactor = ChainAccountInteractorInputSpy(chainAsset: chainAsset)
        let wireframe = ChainAccountWireframeSpy()
        let factory = ChainAccountViewModelFactorySpy()
        let balanceInfoModule = BalanceInfoModuleInputSpy()
        let moduleOutput = ChainAccountModuleOutputSpy()
        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: factory,
            logger: LoggerSpy(),
            wallet: wallet,
            moduleOutput: moduleOutput,
            balanceInfoModule: balanceInfoModule,
            localizationManager: LocalizationManager.shared,
            balanceViewModelFactory: StubBalanceViewModelFactory(),
            mode: mode
        )
        let view = ChainAccountViewSpy()
        presenter.view = view

        return ChainAccountFixture(
            presenter: presenter,
            interactor: interactor,
            wireframe: wireframe,
            factory: factory,
            balanceInfoModule: balanceInfoModule,
            moduleOutput: moduleOutput,
            view: view,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    private static func makeChainAsset() -> ChainAsset {
        ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("xor", symbol: "xor", assetPresicion: 18),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 69)
        )
    }
}

private struct ChainAccountFixture {
    let presenter: ChainAccountPresenter
    let interactor: ChainAccountInteractorInputSpy
    let wireframe: ChainAccountWireframeSpy
    let factory: ChainAccountViewModelFactorySpy
    let balanceInfoModule: BalanceInfoModuleInputSpy
    let moduleOutput: ChainAccountModuleOutputSpy
    let view: ChainAccountViewSpy
    let chainAsset: ChainAsset
    let wallet: MetaAccountModel
}

private final class ChainAccountViewSpy: ChainAccountViewProtocol {
    let controller = UIViewController()
    let isSetup = false
    let contentView = UIView()
    var contentInsets: UIEdgeInsets = .zero
    var preferredContentHeight: CGFloat = 0
    let observable = ViewModelObserverContainer<ContainableObserver>()

    private(set) var loadedViewModel: ChainAccountViewModel?
    private(set) var balanceViewModel: ChainAccountBalanceViewModel?
    var onDidReceiveState: ((ChainAccountViewState) -> Void)?

    func didReceiveState(_ state: ChainAccountViewState) {
        if case let .loaded(viewModel) = state {
            loadedViewModel = viewModel
        }
        onDidReceiveState?(state)
    }

    func didReceive(balanceViewModel: ChainAccountBalanceViewModel?) {
        self.balanceViewModel = balanceViewModel
    }

    func setContentInsets(_ contentInsets: UIEdgeInsets, animated _: Bool) {
        self.contentInsets = contentInsets
    }
}

private final class ChainAccountInteractorInputSpy: ChainAccountInteractorInputProtocol {
    var chainAsset: ChainAsset
    var availableChainAssets: [ChainAsset]
    var isClaimAvailable = false

    private(set) var didSetup = false
    private(set) var didUpdateData = false
    private(set) var exportAddress: String?
    private(set) var updatedChain: ChainModel?

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
        availableChainAssets = [chainAsset]
    }

    func setup() {
        didSetup = true
    }

    func getAvailableExportOptions(for address: String) {
        exportAddress = address
    }

    func update(chain: ChainModel) {
        updatedChain = chain
    }

    func updateData() {
        didUpdateData = true
    }

    func checkIsClaimAvailable() -> Bool {
        isClaimAvailable
    }
}

private final class ChainAccountViewModelFactorySpy: ChainAccountViewModelFactoryProtocol {
    private(set) var receivedChainAsset: ChainAsset?
    private(set) var receivedWallet: MetaAccountModel?
    private(set) var receivedMode: ChainAccountViewMode?

    func buildChainAccountViewModel(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        mode: ChainAccountViewMode
    ) -> ChainAccountViewModel {
        receivedChainAsset = chainAsset
        receivedWallet = wallet
        receivedMode = mode

        return ChainAccountViewModel(
            walletName: wallet.name,
            selectedChainName: chainAsset.chain.name,
            selectedChainIcon: nil,
            address: "address",
            assetModel: chainAsset.asset,
            buyButtonVisible: false,
            polkaswapButtonVisible: false,
            xcmButtomVisible: false,
            mode: mode
        )
    }
}

private final class BalanceInfoModuleInputSpy: BalanceInfoModuleInput {
    private(set) var infoType: BalanceInfoType?

    func replace(infoType: BalanceInfoType) {
        self.infoType = infoType
    }
}

private final class ChainAccountModuleOutputSpy: ChainAccountModuleOutput {
    private(set) var updatedChainAsset: ChainAsset?

    func updateTransactionHistory(for chainAsset: ChainAsset?) {
        updatedChainAsset = chainAsset
    }
}

private final class ChainAccountWireframeSpy: ChainAccountWireframeProtocol {
    private(set) weak var closedView: ControllerBackedProtocol?
    private(set) var detailsChainAsset: ChainAsset?
    private(set) var sendChainAsset: ChainAsset?
    private(set) var sendWallet: MetaAccountModel?
    private(set) var receiveAsset: AssetModel?
    private(set) var crossChainAsset: ChainAsset?
    private(set) var polkaswapChainAsset: ChainAsset?
    private(set) var lockedInfoChainAsset: ChainAsset?
    private(set) var exportOptions: [ExportOption]?
    private(set) var exportWallet: MetaAccountModel?
    private(set) var nodeSelectionChain: ChainModel?
    private(set) var chainActionItems: [ChainAction] = []
    private(set) var chainActionCallback: ModalPickerSelectionCallback?
    private(set) var claimChainAsset: ChainAsset?
    private(set) var statusWasPresented = false

    func close(view: ControllerBackedProtocol?) {
        closedView = view
    }

    func showDetails(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        detailsChainAsset = chainAsset
    }

    func presentSendFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        sendChainAsset = chainAsset
        sendWallet = wallet
    }

    func presentReceiveFlow(
        from _: ControllerBackedProtocol?,
        asset: AssetModel,
        chain _: ChainModel,
        wallet _: MetaAccountModel
    ) {
        receiveAsset = asset
    }

    func presentBuyFlow(
        from _: ControllerBackedProtocol?,
        items _: [PurchaseAction],
        delegate _: ModalPickerViewControllerDelegate
    ) {}

    func presentPurchaseWebView(from _: ControllerBackedProtocol?, action _: PurchaseAction) {}

    func presentChainActionsFlow(
        from _: ControllerBackedProtocol?,
        items: [ChainAction],
        chain _: ChainModel,
        callback: @escaping ModalPickerSelectionCallback
    ) {
        chainActionItems = items
        chainActionCallback = callback
    }

    func presentNodeSelection(from _: ControllerBackedProtocol?, chain: ChainModel) {
        nodeSelectionChain = chain
    }

    func showExport(
        for _: String,
        chain _: ChainModel,
        options: [ExportOption],
        locale _: Locale?,
        wallet: MetaAccountModel,
        from _: ControllerBackedProtocol?
    ) {
        exportOptions = options
        exportWallet = wallet
    }

    func showUniqueChainSourceSelection(
        from _: ControllerBackedProtocol?,
        items _: [ReplaceChainOption],
        callback _: @escaping ModalPickerSelectionCallback
    ) {}

    func showCreate(uniqueChainModel _: UniqueChainModel, from _: ControllerBackedProtocol?) {}
    func showImport(uniqueChainModel _: UniqueChainModel, from _: ControllerBackedProtocol?) {}

    func showSelectNetwork(
        from _: ChainAccountViewProtocol?,
        wallet _: MetaAccountModel,
        selectedChainId _: ChainModel.Id?,
        chainModels _: [ChainModel]?,
        delegate _: SelectNetworkDelegate?
    ) {}

    func showPolkaswap(
        from _: ChainAccountViewProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        polkaswapChainAsset = chainAsset
    }

    func presentLockedInfo(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        lockedInfoChainAsset = chainAsset
    }

    func presentCrossChainFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        crossChainAsset = chainAsset
    }

    func showClaimCrowdloanRewardsFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        claimChainAsset = chainAsset
    }

    @discardableResult
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        true
    }

    func present(
        viewModel _: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {}

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(message _: String?, title _: String, from _: ControllerBackedProtocol?) {}
    func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?, completion closure: (() -> Void)?) {}
    func showAuthorizationCompletion(with _: Bool) {}

    func presentStatus(with _: ApplicationStatusAlertEvent, animated _: Bool) {
        statusWasPresented = true
    }

    func dismissStatus(with _: ApplicationStatusAlertEvent?, animated _: Bool) {}
}

private final class LoggerSpy: LoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
    func customError(error _: Error, file _: String, function _: String, line _: Int) {}
}

private final class SelectNetworkViewInputStub: SelectNetworkViewInput {
    let controller = UIViewController()
    let isSetup = false

    func didReload() {}
    func bind(viewModel _: TextSearchViewModel?) {}
    func reloadCell(at _: IndexPath) {}
}

private extension ChainAction {
    var testCaseName: String {
        switch self {
        case .copyAddress:
            return "copyAddress"
        case .polkascan:
            return "polkascan"
        case .subscan:
            return "subscan"
        case .etherscan:
            return "etherscan"
        case .oklink:
            return "oklink"
        case .switchNode:
            return "switchNode"
        case .export:
            return "export"
        case .replace:
            return "replace"
        case .reefscan:
            return "reefscan"
        case .claimCrowdloanRewards:
            return "claimCrowdloanRewards"
        }
    }
}
