import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class AssetNetworksTests: XCTestCase {
    func testDidLoad_whenViewProvided_thenSetsUpInteractor() {
        let interactor = AssetNetworksInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = AssetNetworksViewSpy()

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
    }

    func testDidReceiveChainSettings_whenChainAssetsKnown_thenBuildsViewModels() {
        let chainAsset = makeChainAsset()
        let expectedViewModels = [makeCellModel(chainAsset: chainAsset, title: "SORA")]
        let factory = AssetNetworksViewModelFactorySpy(viewModels: expectedViewModels)
        let presenter = createPresenter(viewModelFactory: factory)
        let view = AssetNetworksViewSpy()
        let expectation = expectation(description: "view models delivered")
        view.onDidReceiveViewModels = { _ in expectation.fulfill() }

        presenter.didLoad(view: view)
        presenter.didReceiveChainAssets([chainAsset])
        presenter.didReceive(chainSettings: [ChainSettings.defaultSettings(for: chainAsset.chain.chainId)])

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(factory.receivedChainAssets.map(\.chain.chainId), [chainAsset.chain.chainId])
        XCTAssertEqual(factory.receivedFilter, .allNetworks)
        XCTAssertEqual(factory.receivedSort, .fiat)
        XCTAssertEqual(factory.receivedChainSettings.map(\.chainId), [chainAsset.chain.chainId])
        XCTAssertEqual(view.receivedViewModels?.map(\.chainNameLabelText), ["SORA"])
    }

    func testFiltersAndSort_whenChanged_thenRebuildsWithSelectedValues() {
        let chainAsset = makeChainAsset()
        let factory = AssetNetworksViewModelFactorySpy(viewModels: [makeCellModel(chainAsset: chainAsset)])
        let presenter = createPresenter(viewModelFactory: factory)
        let view = AssetNetworksViewSpy()
        let expectation = expectation(description: "view models delivered twice")
        expectation.expectedFulfillmentCount = 2
        view.onDidReceiveViewModels = { _ in expectation.fulfill() }

        presenter.didLoad(view: view)
        presenter.didReceiveChainAssets([chainAsset])
        presenter.didChangeNetworkSwitcher(segmentIndex: AssetNetworksFilter.myNetworks.rawValue)
        presenter.didFinishWithFilters(filters: [
            FilterSet(
                title: nil,
                items: [AssetNetworksSort(type: .name, selected: true)]
            )
        ])

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(factory.receivedFilter, .myNetworks)
        XCTAssertEqual(factory.receivedSort, .name)
    }

    func testDidTapSortButton_whenViewLoaded_thenShowsSortFilters() {
        let router = AssetNetworksRouterSpy()
        let presenter = createPresenter(router: router)
        let view = AssetNetworksViewSpy()

        presenter.didLoad(view: view)
        presenter.didTapSortButton()

        XCTAssertEqual(router.filterTitle, R.string.localizable.commonFilterSortHeader())
        XCTAssertEqual(router.filters.first?.items.count, 3)
        XCTAssertTrue(router.filtersModuleOutput === presenter)
        XCTAssertTrue(router.filtersView === view)
    }

    func testRouteActions_whenTriggered_thenForwardExpectedContext() {
        let router = AssetNetworksRouterSpy()
        let wallet = AccountGenerator.generateMetaAccount()
        let chainAsset = makeChainAsset()
        let otherChain = ChainModelGenerator.generate(count: 1).first!
        let presenter = createPresenter(router: router, wallet: wallet)
        let view = AssetNetworksViewSpy()

        presenter.didLoad(view: view)
        presenter.didSelect(chainAsset: chainAsset)
        presenter.didReceiveChainsWithIssues([
            .network(chains: [chainAsset.chain, otherChain]),
            .missingAccount(chains: [chainAsset.chain])
        ])
        presenter.didTapResolveIssue(for: chainAsset)

        XCTAssertTrue(router.detailsView === view)
        XCTAssertEqual(router.detailsChainAsset?.chain.chainId, chainAsset.chain.chainId)
        XCTAssertTrue(router.issueView === view)
        XCTAssertEqual(router.issueWallet?.metaId, wallet.metaId)
        XCTAssertEqual(router.issueChainIds, [chainAsset.chain.chainId, chainAsset.chain.chainId])
    }

    private func createPresenter(
        interactor: AssetNetworksInteractorInput = AssetNetworksInteractorInputSpy(),
        router: AssetNetworksRouterInput = AssetNetworksRouterSpy(),
        wallet: MetaAccountModel = AccountGenerator.generateMetaAccount(),
        viewModelFactory: AssetNetworksViewModelFactoryProtocol = AssetNetworksViewModelFactorySpy()
    ) -> AssetNetworksPresenter {
        AssetNetworksPresenter(
            interactor: interactor,
            router: router,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            viewModelFactory: viewModelFactory
        )
    }

    private func makeChainAsset() -> ChainAsset {
        ChainModelGenerator.generateChainAsset(
            ChainModelGenerator.generateAssetWithId("asset-id", symbol: "xor"),
            chain: ChainModelGenerator.generate(count: 1).first!
        )
    }

    private func makeCellModel(
        chainAsset: ChainAsset,
        title: String = "Network"
    ) -> AssetNetworksTableCellModel {
        AssetNetworksTableCellModel(
            iconViewModel: nil,
            chainNameLabelText: title,
            cryptoBalanceLabelText: "1 XOR",
            fiatBalanceLabelText: "$1",
            chainAsset: chainAsset,
            hasIssues: false
        )
    }
}

private final class AssetNetworksViewSpy: AssetNetworksViewInput {
    let controller = UIViewController()
    let isSetup = false
    let draggableView = UIView()
    weak var delegate: DraggableDelegate?
    let scrollPanRecognizer: UIPanGestureRecognizer? = nil
    private(set) var receivedViewModels: [AssetNetworksTableCellModel]?
    var onDidReceiveViewModels: (([AssetNetworksTableCellModel]) -> Void)?

    func didReceive(viewModels: [AssetNetworksTableCellModel]) {
        receivedViewModels = viewModels
        onDidReceiveViewModels?(viewModels)
    }

    func set(dragableState _: DraggableState, animated _: Bool) {}
    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}
    func canDrag(from _: DraggableState) -> Bool { true }
    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame _: CGRect) {}
}

private final class AssetNetworksInteractorInputSpy: AssetNetworksInteractorInput {
    private(set) weak var output: AssetNetworksInteractorOutput?

    func setup(with output: AssetNetworksInteractorOutput) {
        self.output = output
    }
}

private final class AssetNetworksRouterSpy: AssetNetworksRouterInput {
    private(set) weak var detailsView: ControllerBackedProtocol?
    private(set) weak var filtersView: ControllerBackedProtocol?
    private(set) weak var issueView: ControllerBackedProtocol?
    private(set) weak var filtersModuleOutput: FiltersModuleOutput?
    private(set) var detailsChainAsset: ChainAsset?
    private(set) var filterTitle: String?
    private(set) var filters: [FilterSet] = []
    private(set) var issueWallet: MetaAccountModel?
    private(set) var issueChainIds: [ChainModel.Id] = []

    func showDetails(
        from view: ControllerBackedProtocol?,
        chainAsset: ChainAsset
    ) {
        detailsView = view
        detailsChainAsset = chainAsset
    }

    func showFilters(
        title: String?,
        filters: [FilterSet],
        moduleOutput: FiltersModuleOutput?,
        from view: ControllerBackedProtocol?
    ) {
        filterTitle = title
        self.filters = filters
        filtersModuleOutput = moduleOutput
        filtersView = view
    }

    func showIssueNotification(
        from view: ControllerBackedProtocol?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    ) {
        issueView = view
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
}

private final class AssetNetworksViewModelFactorySpy: AssetNetworksViewModelFactoryProtocol {
    private(set) var receivedChainAssets: [ChainAsset] = []
    private(set) var receivedAccountInfos: [ChainAssetKey: AccountInfo?] = [:]
    private(set) var receivedWallet: MetaAccountModel?
    private(set) var receivedFilter: AssetNetworksFilter?
    private(set) var receivedSort: AssetNetworksSortType?
    private(set) var receivedChainsWithIssue: [ChainIssue] = []
    private(set) var receivedChainSettings: [ChainSettings] = []
    private let viewModels: [AssetNetworksTableCellModel]

    init(viewModels: [AssetNetworksTableCellModel] = []) {
        self.viewModels = viewModels
    }

    func buildViewModels(
        chainAssets: [ChainAsset],
        accountInfos: [ChainAssetKey: AccountInfo?],
        wallet: MetaAccountModel,
        locale _: Locale,
        filter: AssetNetworksFilter,
        sort: AssetNetworksSortType,
        chainsWithIssue: [ChainIssue],
        chainSettings: [ChainSettings]
    ) -> [AssetNetworksTableCellModel] {
        receivedChainAssets = chainAssets
        receivedAccountInfos = accountInfos
        receivedWallet = wallet
        receivedFilter = filter
        receivedSort = sort
        receivedChainsWithIssue = chainsWithIssue
        receivedChainSettings = chainSettings
        return viewModels
    }
}
