import XCTest
import UIKit
import SoraFoundation
import SSFModels
import RobinHood
@testable import fearless

final class CovJSelAssetNetworksOutputSpy: AssetNetworksViewOutput {
    private(set) var loadedViews: [AssetNetworksViewInput] = []
    private(set) var selected: [ChainAsset] = []
    private(set) var segments: [Int] = []
    private(set) var sortTaps = 0
    private(set) var resolved: [ChainAsset] = []

    func didLoad(view: AssetNetworksViewInput) { loadedViews.append(view) }
    func didSelect(chainAsset: ChainAsset) { selected.append(chainAsset) }
    func didChangeNetworkSwitcher(segmentIndex: Int) { segments.append(segmentIndex) }
    func didTapSortButton() { sortTaps += 1 }
    func didTapResolveIssue(for chainAsset: ChainAsset) { resolved.append(chainAsset) }
}

final class CovJSelAssetNetworksCellDelegateSpy: AssetNetworksTableCellDelegate {
    private(set) var resolved: [ChainAsset] = []

    func resolveIssue(for chainAsset: ChainAsset) {
        resolved.append(chainAsset)
    }
}

final class CovJSelInteractorOutputSpy: AssetNetworksInteractorOutput {
    private(set) var chainAssets: [[ChainAsset]] = []
    private(set) var accountInfos: [(Result<AccountInfo?, Error>, ChainAsset)] = []
    private(set) var settings: [[ChainSettings]] = []
    private(set) var issues: [[ChainIssue]] = []

    func didReceiveChainAssets(_ chainAssets: [ChainAsset]) { self.chainAssets.append(chainAssets) }
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAsset: ChainAsset) { accountInfos.append((result, chainAsset)) }
    func didReceive(chainSettings: [ChainSettings]) { settings.append(chainSettings) }
    func didReceiveChainsWithIssues(_ issues: [ChainIssue]) { self.issues.append(issues) }
}

final class CovJSelWalletSubscriptionFactoryStub: WalletLocalSubscriptionFactoryProtocol {
    let operationManager: OperationManagerProtocol = OperationManager()
    let processingQueue: DispatchQueue? = nil
    private(set) var requested: [ChainAsset] = []

    func getAccountProvider(for _: AccountId, chainAsset: ChainAsset) throws -> StreamableProvider<AccountInfoStorageWrapper> {
        requested.append(chainAsset)
        throw CovJError("no local storage in tests")
    }

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        nil
    }
}

final class CovJSelNetworkIssuesCenterStub: NetworkIssuesCenterProtocol {
    func addIssuesListener(_: NetworkIssuesCenterListener, getExisting _: Bool) {}
    func removeIssuesListener(_: NetworkIssuesCenterListener) {}
    func forceNotify() {}
}

struct CovJSelNoMissingAccounts: MissingAccountFetcherProtocol {
    func fetchMissingAccounts(for _: MetaAccountModel, complection: @escaping ([ChainModel]) -> Void) {
        complection([])
    }
}

struct CovJSelNoAccountInfo: AccountInfoFetchingProtocol {
    func fetch(for chainAsset: ChainAsset, accountId _: AccountId, completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void) {
        completionBlock(chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel, completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void) {
        completionBlock([:])
    }

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] {
        [:]
    }

    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
    }
}

final class CovJSelChainSettingsRepository: AsyncCoreDataRepository {
    typealias Model = ChainSettings

    func fetch(by _: [String], options _: RepositoryFetchOptions) async throws -> [ChainSettings] { [] }
    func fetch(by _: String, options _: RepositoryFetchOptions) async throws -> ChainSettings? { nil }
    func fetchAll(with _: RepositoryFetchOptions) async throws -> [ChainSettings] { [] }
    func save(models _: [ChainSettings], deleteIds _: [String]) async {}
}

final class CovJSelAssetNetworksViewsTests: XCTestCase {
    private func model(_ chainAsset: ChainAsset, name: String, issues: Bool, icon: RemoteImageViewModel? = nil) -> AssetNetworksTableCellModel {
        AssetNetworksTableCellModel(iconViewModel: icon, chainNameLabelText: name, cryptoBalanceLabelText: "1.5 \(name)",
                                    fiatBalanceLabelText: "$3", chainAsset: chainAsset, hasIssues: issues)
    }

    func testCellShowsBalancesOrWarningAndReportsIssueTaps() throws {
        let chainAsset = CovJFixture.chainAsset(chainName: "Cell", symbol: "CEL")
        let cell = AssetNetworksTableCell(style: .default, reuseIdentifier: nil)
        cell.frame = CGRect(x: 0, y: 0, width: 358, height: 80)
        cell.layoutIfNeeded()
        let delegate = CovJSelAssetNetworksCellDelegateSpy()
        cell.delegate = delegate
        XCTAssertEqual(cell.selectionStyle, .none)
        XCTAssertEqual(cell.backgroundColor, .clear)
        XCTAssertTrue(cell.warningButton.superview === cell.balanceStackView)

        cell.bind(viewModel: model(chainAsset, name: "Cell", issues: false, icon: CovJSelFixture.offlineIcon))
        XCTAssertEqual(cell.chainNameLabel.text, "Cell")
        XCTAssertEqual(cell.cryptoBalanceLabel.text, "1.5 Cell")
        XCTAssertEqual(cell.fiatBalanceLabel.text, "$3")
        XCTAssertFalse(cell.cryptoBalanceLabel.isHidden)
        XCTAssertFalse(cell.fiatBalanceLabel.isHidden)
        XCTAssertTrue(cell.warningButton.isHidden)
        XCTAssertTrue(CovJWait.until { cell.networkIconImageView.image != nil })

        cell.bind(viewModel: model(chainAsset, name: "Cell", issues: true))
        XCTAssertTrue(cell.cryptoBalanceLabel.isHidden)
        XCTAssertTrue(cell.fiatBalanceLabel.isHidden)
        XCTAssertFalse(cell.warningButton.isHidden)
        XCTAssertNotNil(cell.warningButton.image(for: .normal))
        cell.warningButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.resolved, [chainAsset])

        cell.prepareForReuse()
        cell.warningButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.resolved.count, 1, "a reused cell has no network to resolve")
    }

    func testControllerListsNetworksAndForwardsEveryAction() throws {
        let first = CovJFixture.chainAsset(chainName: "First", symbol: "FST")
        let second = CovJFixture.chainAsset(chainName: "Second", symbol: "SND")
        let output = CovJSelAssetNetworksOutputSpy()
        let controller = AssetNetworksViewController(output: output, localizationManager: try CovJSelFixture.manager())
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }

        XCTAssertTrue(output.loadedViews.first === controller)
        XCTAssertTrue(controller.draggableView === controller.rootView)
        XCTAssertNil(controller.scrollPanRecognizer)
        XCTAssertTrue(controller.canDrag(from: .compact))
        controller.set(dragableState: .full, animated: false)
        controller.set(contentInsets: .zero, for: .full)
        controller.animate(progress: 0.5, from: .compact, to: .full, finalFrame: .zero)
        controller.applyLocalization()

        controller.didReceive(viewModels: [model(first, name: "First", issues: false), model(second, name: "Second", issues: true)])
        let table = controller.rootView.tableView
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 80)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? AssetNetworksTableCell)
        XCTAssertEqual(cell.chainNameLabel.text, "Second")
        XCTAssertTrue(cell.delegate === controller)
        cell.warningButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.resolved, [second])

        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 9, section: 0))
        XCTAssertEqual(output.selected, [first])

        controller.didSelect(1)
        XCTAssertEqual(output.segments, [1])
        XCTAssertTrue(controller.rootView.networkSwitcher.delegate === controller)
        controller.rootView.sortButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.sortTaps, 1)
    }

    func testRouterPresentsSingleSelectionSortFilters() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let router = AssetNetworksRouter()
        router.showFilters(title: "Sort", filters: [], moduleOutput: nil, from: nil)
        XCTAssertNil(host.presented)
        let sorts = FilterSet(title: nil, items: AssetNetworksSort.defaultFilters(selected: .fiat))
        router.showFilters(title: "Sort", filters: [sorts], moduleOutput: nil, from: host)
        XCTAssertTrue(host.presented is FiltersViewController)
        XCTAssertEqual(host.presented?.modalPresentationStyle, .custom)
    }

    func testInteractorPublishesMatchingAssetsIssuesAndBalances() throws {
        let wallet = CovJSelFixture.substrateWallet()
        let source = ChainAsset(chain: CovJSelFixture.chain(name: "Source", assets: []), asset: CovJSelFixture.asset("src"))
        let other = ChainAsset(chain: CovJSelFixture.chain(name: "Other", assets: []), asset: CovJSelFixture.asset("other"))
        let fetching = CovJSelChainAssetFetchingStub(result: .success([source, other]))
        let subscriptionFactory = CovJSelWalletSubscriptionFactoryStub()
        let issuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: CovJSelNetworkIssuesCenterStub(),
            eventCenter: EventCenter(),
            missingAccountHelper: CovJSelNoMissingAccounts(),
            accountInfoFetcher: CovJSelNoAccountInfo()
        )
        let interactor = AssetNetworksInteractor(
            chainAsset: source,
            wallet: wallet,
            chainAssetFetching: fetching,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(walletLocalSubscriptionFactory: subscriptionFactory,
                                                                           selectedMetaAccount: wallet),
            chainsIssuesCenter: issuesCenter,
            chainSettingsRepository: AsyncAnyRepository(CovJSelChainSettingsRepository()),
            catalog: CanonicalTokenGroupCatalog(data: nil, testnets: .bundled)
        )
        let output = CovJSelInteractorOutputSpy()

        interactor.setup(with: output)
        XCTAssertEqual(output.issues.count, 1, "existing issues are delivered on setup")
        XCTAssertTrue(output.issues.first?.isEmpty == true)
        XCTAssertEqual(fetching.requestedFilters.count, 1)
        XCTAssertTrue(CovJWait.until { output.chainAssets.count == 1 })
        XCTAssertEqual(output.chainAssets.first, [source], "only the same asset is a member without a catalog group")
        XCTAssertEqual(subscriptionFactory.requested, [source])

        interactor.handleChainsIssues([.network(chains: [source.chain])])
        XCTAssertEqual(output.issues.count, 2)
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        interactor.handleAccountInfo(result: .success(nil), accountId: accountId, chainAsset: source)
        XCTAssertEqual(output.accountInfos.first?.1, source)
        XCTAssertTrue(CovJWait.until { output.settings.count == 2 }, "the muted networks are read with every issues update")
        XCTAssertEqual(output.settings.last, [])
    }

    func testInteractorPublishesNoAssetsWhenFetchingFails() {
        let wallet = CovJSelFixture.substrateWallet()
        let source = ChainAsset(chain: CovJSelFixture.chain(name: "Source", assets: []), asset: CovJSelFixture.asset("src"))
        let interactor = AssetNetworksInteractor(
            chainAsset: source,
            wallet: wallet,
            chainAssetFetching: CovJSelChainAssetFetchingStub(result: .failure(CovJError("fetch"))),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(walletLocalSubscriptionFactory: CovJSelWalletSubscriptionFactoryStub(),
                                                                           selectedMetaAccount: wallet),
            chainsIssuesCenter: ChainsIssuesCenter(
                wallet: wallet,
                networkIssuesCenter: CovJSelNetworkIssuesCenterStub(),
                eventCenter: EventCenter(),
                missingAccountHelper: CovJSelNoMissingAccounts(),
                accountInfoFetcher: CovJSelNoAccountInfo()
            ),
            chainSettingsRepository: AsyncAnyRepository(CovJSelChainSettingsRepository())
        )
        let output = CovJSelInteractorOutputSpy()
        interactor.setup(with: output)
        XCTAssertTrue(CovJWait.until { output.chainAssets.count == 1 })
        XCTAssertEqual(output.chainAssets.first, [])
    }
}
