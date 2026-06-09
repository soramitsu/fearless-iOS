import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class ChainAccountListTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractor() {
        let fixture = makeFixture()
        let view = ChainAssetListViewSpy()

        fixture.presenter.didLoad(view: view)

        XCTAssertTrue(fixture.interactor.output === fixture.presenter)
    }

    func testDidReceiveChainAssets_whenSuccessful_thenBuildsAndDeliversViewModel() {
        let chainAsset = Self.makeChainAsset()
        let expectedViewModel = ChainAssetListViewModel(displayState: .defaultList(cells: [
            Self.makeCellModel(chainAsset: chainAsset)
        ], withAnimate: false))
        let factory = ChainAssetListViewModelFactorySpy(viewModel: expectedViewModel)
        let fixture = makeFixture(viewModelFactory: factory)
        let view = ChainAssetListViewSpy()
        let expectation = expectation(description: "view model delivered")
        view.onDidReceiveViewModel = { _ in expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didReceiveChainAssets(result: Result<[ChainAsset], Error>.success([chainAsset]))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(factory.receivedChainAssets.map { $0.chain.chainId }, [chainAsset.chain.chainId])
        XCTAssertTrue(factory.receivedDisplayType?.isAssetChains == true)
        XCTAssertEqual(view.receivedViewModel?.displayState.rows.map { $0.chainAsset.chain.chainId }, [chainAsset.chain.chainId])
    }

    func testUpdateChainAssets_whenFiltersChange_thenUpdatesDisplayTypeAndManageFilter() {
        let chainAsset = Self.makeChainAsset()
        let factory = ChainAssetListViewModelFactorySpy()
        let fixture = makeFixture(viewModelFactory: factory)
        let view = ChainAssetListViewSpy()
        let expectation = expectation(description: "view model delivered")
        view.onDidReceiveViewModel = { _ in expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.updateChainAssets(
            using: [.chainId(chainAsset.chain.chainId)],
            sorts: [.assetName(.ascending)],
            networkFilter: .chain(chainAsset.chain.chainId)
        )
        fixture.presenter.didReceiveChainAssets(result: Result<[ChainAsset], Error>.success([chainAsset]))
        fixture.presenter.didTapManageAsset()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.interactor.receivedFilters, [.chainId(chainAsset.chain.chainId)])
        XCTAssertTrue(fixture.interactor.didUseCache)
        XCTAssertTrue(factory.receivedDisplayType?.isChain == true)
        XCTAssertEqual(fixture.router.manageWallet?.metaId, fixture.wallet.metaId)
        XCTAssertEqual(fixture.router.manageFilter?.identifier, chainAsset.chain.chainId)
    }

    func testDidSelectViewModel_whenOneNetworkAvailable_thenShowsChainAccount() {
        let chainAsset = Self.makeChainAsset()
        let fixture = makeFixture()
        let view = ChainAssetListViewSpy()
        let expectation = expectation(description: "chain account route")
        fixture.interactor.availableChainAssets = [chainAsset]
        fixture.router.onShowChainAccount = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didSelectViewModel(Self.makeCellModel(chainAsset: chainAsset))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.router.chainAccountChainAsset?.chain.chainId, chainAsset.chain.chainId)
    }

    func testDidSelectViewModel_whenMultipleNetworksAvailable_thenShowsAssetNetworks() {
        let chainAsset = Self.makeChainAsset()
        let alternativeChainAsset = Self.makeChainAsset(asset: chainAsset.asset)
        let fixture = makeFixture()
        let view = ChainAssetListViewSpy()
        let expectation = expectation(description: "asset networks route")
        fixture.interactor.availableChainAssets = [chainAsset, alternativeChainAsset]
        fixture.router.onShowAssetNetworks = { expectation.fulfill() }

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didSelectViewModel(Self.makeCellModel(chainAsset: chainAsset))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(fixture.router.assetNetworksChainAsset?.chain.chainId, chainAsset.chain.chainId)
    }

    func testActionButtonsAndRefresh_whenTriggered_thenDelegateToRouterAndInteractor() {
        let chainAsset = Self.makeChainAsset()
        let fixture = makeFixture()
        let view = ChainAssetListViewSpy()
        let cellModel = Self.makeCellModel(chainAsset: chainAsset)

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapAction(actionType: .send, viewModel: cellModel)
        fixture.presenter.didTapAction(actionType: .receive, viewModel: cellModel)
        fixture.presenter.didTapAction(actionType: .hide, viewModel: cellModel)
        fixture.presenter.didPullToRefresh()
        fixture.presenter.didTapResolveNetworkIssue(for: chainAsset.chain)

        XCTAssertEqual(fixture.router.sendChainAsset?.chain.chainId, chainAsset.chain.chainId)
        XCTAssertEqual(fixture.router.receiveChainAsset?.chain.chainId, chainAsset.chain.chainId)
        XCTAssertEqual(fixture.interactor.hiddenChainAsset?.chain.chainId, chainAsset.chain.chainId)
        XCTAssertTrue(fixture.interactor.didReload)
        XCTAssertEqual(fixture.interactor.retryChainId, chainAsset.chain.chainId)
    }

    func testResolveAccountIssue_whenActionsSelected_thenRoutesCreateImportAndSkip() throws {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let fixture = makeFixture()
        let view = ChainAssetListViewSpy()

        fixture.presenter.didLoad(view: view)
        fixture.presenter.didTapResolveAccountIssue(for: chain)

        XCTAssertEqual(fixture.router.accountOptionsActions.count, 3)
        fixture.router.accountOptionsActions[0].handler?()
        fixture.router.accountOptionsActions[1].handler?()
        fixture.router.accountOptionsActions[2].handler?()

        XCTAssertEqual(fixture.router.createUniqueChain?.chain.chainId, chain.chainId)
        XCTAssertEqual(fixture.router.importUniqueChain?.chain.chainId, chain.chainId)
        XCTAssertEqual(fixture.interactor.markedUnusedChain?.chainId, chain.chainId)
    }

    private func makeFixture(
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        viewModelFactory: ChainAssetListViewModelFactoryProtocol = ChainAssetListViewModelFactorySpy()
    ) -> ChainAssetListFixture {
        let interactor = ChainAssetListInteractorInputSpy()
        let router = ChainAssetListRouterSpy()
        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: viewModelFactory
        )

        return ChainAssetListFixture(
            presenter: presenter,
            interactor: interactor,
            router: router,
            wallet: wallet
        )
    }

    private static func makeChainAsset(asset: AssetModel? = nil) -> ChainAsset {
        ChainModelGenerator.generateChainAsset(
            asset ?? ChainModelGenerator.generateAssetWithId("xor", symbol: "xor", assetPresicion: 18),
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        )
    }

    private static func makeCellModel(chainAsset: ChainAsset) -> ChainAccountBalanceCellViewModel {
        ChainAccountBalanceCellViewModel(
            assetContainsChainAssets: [chainAsset],
            chainIconViewViewModel: ChainCollectionViewModel(maxImagesCount: 5, chainImages: []),
            chainAsset: chainAsset,
            assetName: chainAsset.asset.name,
            assetInfo: nil,
            imageViewModel: nil,
            balanceString: .normal("1 XOR"),
            priceAttributedString: .normalAttributed(NSAttributedString(string: "$1")),
            totalAmountString: .normal("$1"),
            options: nil,
            isColdBoot: false,
            locale: Locale(identifier: "en_US"),
            hideButtonIsVisible: true
        )
    }
}

private struct ChainAssetListFixture {
    let presenter: ChainAssetListPresenter
    let interactor: ChainAssetListInteractorInputSpy
    let router: ChainAssetListRouterSpy
    let wallet: MetaAccountModel
}

private final class ChainAssetListViewSpy: ChainAssetListViewInput {
    let controller = UIViewController()
    let isSetup = false
    private(set) var receivedViewModel: ChainAssetListViewModel?
    private(set) var didReloadBanners = false
    var onDidReceiveViewModel: ((ChainAssetListViewModel) -> Void)?

    func didReceive(viewModel: ChainAssetListViewModel) {
        receivedViewModel = viewModel
        onDidReceiveViewModel?(viewModel)
    }

    func reloadBanners() {
        didReloadBanners = true
    }
}

private final class ChainAssetListInteractorInputSpy: ChainAssetListInteractorInput {
    var shouldRunManageAssetAnimate = true
    var availableChainAssets: [ChainAsset] = []

    private(set) weak var output: ChainAssetListInteractorOutput?
    private(set) var receivedFilters: [ChainAssetsFetching.Filter] = []
    private(set) var receivedSorts: [ChainAssetsFetching.SortDescriptor] = []
    private(set) var didUseCache = false
    private(set) var markedUnusedChain: ChainModel?
    private(set) var didReload = false
    private(set) var hiddenChainAsset: ChainAsset?
    private(set) var retryChainId: ChainModel.Id?

    func setup(with output: ChainAssetListInteractorOutput) {
        self.output = output
    }

    func updateChainAssets(
        using filters: [ChainAssetsFetching.Filter],
        sorts: [ChainAssetsFetching.SortDescriptor],
        useCashe: Bool
    ) {
        receivedFilters = filters
        receivedSorts = sorts
        didUseCache = useCashe
    }

    func markUnused(chain: ChainModel) {
        markedUnusedChain = chain
    }

    func reload() {
        didReload = true
    }

    func getAvailableChainAssets(
        chainAsset: ChainAsset,
        completion: @escaping (([ChainAsset]) -> Void)
    ) {
        completion(availableChainAssets.isEmpty ? [chainAsset] : availableChainAssets)
    }

    func hideChainAsset(_ chainAsset: ChainAsset) {
        hiddenChainAsset = chainAsset
    }

    func retryConnection(for chainId: ChainModel.Id) {
        retryChainId = chainId
    }
}

private final class ChainAssetListRouterSpy: ChainAssetListRouterInput {
    private(set) var assetNetworksChainAsset: ChainAsset?
    private(set) var chainAccountChainAsset: ChainAsset?
    private(set) var sendChainAsset: ChainAsset?
    private(set) var receiveChainAsset: ChainAsset?
    private(set) var accountOptionsActions: [SheetAlertPresentableAction] = []
    private(set) var createUniqueChain: UniqueChainModel?
    private(set) var importUniqueChain: UniqueChainModel?
    private(set) var manageWallet: MetaAccountModel?
    private(set) var manageFilter: NetworkManagmentFilter?
    private(set) var issueWallet: MetaAccountModel?
    private(set) var issueChainIds: [ChainModel.Id] = []
    private(set) var didShowAppstore = false
    private(set) weak var dismissedView: ControllerBackedProtocol?
    var onShowChainAccount: (() -> Void)?
    var onShowAssetNetworks: (() -> Void)?

    func showAssetNetworks(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        assetNetworksChainAsset = chainAsset
        onShowAssetNetworks?()
    }

    func showChainAccount(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        chainAccountChainAsset = chainAsset
        onShowChainAccount?()
    }

    func showSendFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        sendChainAsset = chainAsset
    }

    func showReceiveFlow(
        from _: ControllerBackedProtocol?,
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel
    ) {
        receiveChainAsset = chainAsset
    }

    func presentAccountOptions(
        from _: ControllerBackedProtocol?,
        locale _: Locale?,
        actions: [SheetAlertPresentableAction]
    ) {
        accountOptionsActions = actions
    }

    func showCreate(
        uniqueChainModel: UniqueChainModel,
        from _: ControllerBackedProtocol?
    ) {
        createUniqueChain = uniqueChainModel
    }

    func showImport(
        uniqueChainModel: UniqueChainModel,
        from _: ControllerBackedProtocol?
    ) {
        importUniqueChain = uniqueChainModel
    }

    func showManageAsset(
        from _: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        filter: NetworkManagmentFilter?
    ) {
        manageWallet = wallet
        manageFilter = filter
    }

    func showIssueNotification(
        from _: ControllerBackedProtocol?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    ) {
        issueWallet = wallet
        issueChainIds = issues.flatMap { issue -> [ChainModel.Id] in
            switch issue {
            case let .network(chains):
                return chains.map(\.chainId)
            case let .missingAccount(chains):
                return chains.map(\.chainId)
            }
        }
    }

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentWarningAlert(
        from _: ControllerBackedProtocol?,
        config _: WarningAlertConfig,
        buttonHandler _: @escaping WarningAlertButtonHandler
    ) {}

    func showAppstoreUpdatePage() {
        didShowAppstore = true
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
}

private final class ChainAssetListViewModelFactorySpy: ChainAssetListViewModelFactoryProtocol {
    private(set) var receivedWallet: MetaAccountModel?
    private(set) var receivedChainAssets: [ChainAsset] = []
    private(set) var receivedAccountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private(set) var receivedChainsWithIssue: [ChainIssue] = []
    private(set) var receivedDisplayType: AssetListDisplayType?
    private(set) var receivedChainSettings: [ChainSettings] = []
    private let viewModel: ChainAssetListViewModel

    init(
        viewModel: ChainAssetListViewModel = ChainAssetListViewModel(
            displayState: .defaultList(cells: [], withAnimate: false)
        )
    ) {
        self.viewModel = viewModel
    }

    func buildViewModel(
        wallet: MetaAccountModel,
        chainAssets: [ChainAsset],
        locale _: Locale,
        accountInfos: [ChainAssetKey: AccountInfo?],
        chainsWithIssue: [ChainIssue],
        shouldRunManageAssetAnimate _: Bool,
        displayType: AssetListDisplayType,
        chainSettings: [ChainSettings]
    ) -> ChainAssetListViewModel {
        receivedWallet = wallet
        receivedChainAssets = chainAssets
        receivedAccountInfos = accountInfos
        receivedChainsWithIssue = chainsWithIssue
        receivedDisplayType = displayType
        receivedChainSettings = chainSettings
        return viewModel
    }
}

private extension AssetListDisplayType {
    var isAssetChains: Bool {
        if case .assetChains = self {
            return true
        }
        return false
    }

    var isChain: Bool {
        if case .chain = self {
            return true
        }
        return false
    }
}
