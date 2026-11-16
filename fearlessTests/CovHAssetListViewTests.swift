import XCTest
import UIKit
import SoraFoundation
import SSFModels
@testable import fearless

final class CovHAssetListViewOutputSpy: ChainAssetListViewOutput {
    private(set) var calls: [String] = []
    private(set) var selected: [ChainAccountBalanceCellViewModel] = []
    private(set) var tokenActions: [(SwipableCellButtonType, String)] = []
    private(set) var keptHidden: [[AssetKey]] = []
    private(set) var resolvedChains: [ChainModel.Id] = []

    func didLoad(view _: ChainAssetListViewInput) { calls.append("load") }
    func didSelectViewModel(_ viewModel: ChainAccountBalanceCellViewModel) {
        calls.append("select")
        selected.append(viewModel)
    }

    func didTapAction(actionType _: SwipableCellButtonType, viewModel _: ChainAccountBalanceCellViewModel) { calls.append("action") }
    func didSelectLens(_: PortfolioLens, walletId _: String) { calls.append("lens") }
    func didTapTokenAction(actionType: SwipableCellButtonType, groupId: String, walletId _: String) {
        calls.append("tokenAction")
        tokenActions.append((actionType, groupId))
    }

    func didTapFunding(_: PortfolioFundingAction, walletId _: String) { calls.append("funding") }
    func didPullToRefresh() { calls.append("refresh") }
    func didTapManageAsset() { calls.append("manage") }
    func didTapHiddenAssetsNotIncluded() { calls.append("hiddenAssets") }
    func didTapTestnetAssetsNotIncluded() { calls.append("testnetAssets") }
    func didTapReviewHiddenFunds() { calls.append("reviewHidden") }
    func didTapKeepHiddenFunds(assetKeys: [AssetKey]) {
        calls.append("keepHidden")
        keptHidden.append(assetKeys)
    }

    func didFinishManageAssetAnimate() { calls.append("animationDone") }
    func didTapResolveNetworkIssue(for chain: ChainModel) {
        calls.append("resolveNetwork")
        resolvedChains.append(chain.chainId)
    }

    func didTapResolveAccountIssue(for chain: ChainModel) {
        calls.append("resolveAccount")
        resolvedChains.append(chain.chainId)
    }
}

enum CovHAssetListViews {
    static func find<T: UIView>(_: T.Type, in view: UIView) -> [T] {
        var result: [T] = []
        if let match = view as? T { result.append(match) }
        view.subviews.forEach { result.append(contentsOf: find(T.self, in: $0)) }
        return result
    }

    static func child(_ asset: ChainAsset, amount: Decimal) -> TokenGroupChildModel {
        TokenGroupChildModel(
            chainAsset: asset,
            value: PortfolioHoldingValue(role: .unpriced, amount: amount, transferable: amount, fiat: .zero, dayChange: .zero),
            placement: amount > .zero ? .visible : .zeroCollapsed
        )
    }

    static func row(
        id: String,
        children: [TokenGroupChildModel],
        zeroChildren: [TokenGroupChildModel] = [],
        single: Bool
    ) -> TokenGroupRowViewModel {
        TokenGroupRowViewModel(
            model: TokenGroupRowModel(
                id: id,
                symbol: "COVH",
                name: "Cov H token",
                icon: nil,
                amount: children.reduce(.zero) { $0 + $1.amount },
                fiat: .zero,
                unpricedNetworkCount: 0,
                children: children,
                zeroChildren: zeroChildren,
                isSingleNetwork: single
            ),
            amountText: "1 COVH",
            fiatText: nil
        )
    }

    static func section(
        id: String,
        kind: AssetNetworkSectionKind,
        rows: [ChainAccountBalanceCellViewModel],
        parent: String? = nil
    ) -> AssetNetworkSectionViewModel {
        AssetNetworkSectionViewModel(
            id: id,
            chainId: id,
            kind: kind,
            networkName: "Network \(id)",
            ecosystemName: "Substrate",
            address: nil,
            fiatSubtotal: nil,
            syncStatus: nil,
            detectedCount: 0,
            rows: rows,
            parentSectionId: parent
        )
    }
}

final class CovHAssetListViewTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController(
        banners: UIViewController? = nil,
        keyboardAdoptable: Bool = false
    ) throws -> (ChainAssetListViewController, CovHAssetListViewOutputSpy) {
        let output = CovHAssetListViewOutputSpy()
        let controller = ChainAssetListViewController(
            bannersViewController: banners,
            output: output,
            keyboardAdoptable: keyboardAdoptable,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en")),
            collapseStore: PortfolioCollapseStore(userDefaults: CovHAssetListFixture.defaults())
        )
        window = CovHAssetListFixture.host(controller)
        return (controller, output)
    }

    func testBannersKeyboardAndFlightTiers() throws {
        let banners = UIViewController()
        let (controller, output) = try makeController(banners: banners, keyboardAdoptable: true)

        XCTAssertEqual(output.calls, ["load"])
        XCTAssertTrue(controller.children.contains(banners))
        XCTAssertTrue(controller.rootView.bannersView === banners.view)
        XCTAssertEqual(banners.view.isHidden, true)

        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertTrue(controller.target === controller.rootView.keyboardAdoptableConstraint)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(24), 0)
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 0, width: 10, height: 10))
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)

        let tiers = controller.flightTiers
        XCTAssertEqual(tiers.count, 1)
        XCTAssertTrue(tiers.first?.view === controller.rootView.lensControl)
        XCTAssertEqual(tiers.first?.tier, 3)
    }

    func testFooterFollowsTheListState() throws {
        let (controller, output) = try makeController()
        let chain = CovHAssetListFixture.chain()
        let languages = Locale(identifier: "en").rLanguages
        let walletId = UUID().uuidString
        let footer = controller.rootView.footerButton

        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .chainHasNetworkIssue(chain: chain), networkSections: [], walletId: walletId))
        XCTAssertEqual(footer.title(for: .normal), R.string.localizable.tryAgain(preferredLanguages: languages))
        XCTAssertNil(controller.rootView.tableView.tableFooterView)
        footer.sendActions(for: .touchUpInside)

        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .chainHasAccountIssue(chain: chain), networkSections: [], walletId: walletId))
        XCTAssertEqual(footer.title(for: .normal), R.string.localizable.accountsAddAccount(preferredLanguages: languages))
        footer.sendActions(for: .touchUpInside)

        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .allIsHidden, networkSections: [], walletId: walletId))
        footer.sendActions(for: .touchUpInside)

        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .search(cells: []), networkSections: [], walletId: walletId))
        XCTAssertNil(footer.title(for: .normal))
        XCTAssertTrue(footer.isHidden)
        footer.sendActions(for: .touchUpInside)

        let cell = CovHAssetListPresenterContext.cell(for: CovHAssetListFixture.chainAsset())
        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .search(cells: [cell]), networkSections: [], walletId: walletId))
        XCTAssertNotNil(controller.rootView.tableView.tableFooterView)

        XCTAssertEqual(output.calls, ["load", "resolveNetwork", "resolveAccount", "manage"])
        XCTAssertEqual(output.resolvedChains, [chain.chainId, chain.chainId])
    }

    func testCaptionsNoticeRefreshAndBanners() throws {
        let (controller, output) = try makeController()
        let rootView = controller.rootView

        controller.rootView.removeHeaderView()
        controller.reloadBanners()
        XCTAssertNil(rootView.tableView.tableHeaderView, "Nothing to show before the first list")
        rootView.hiddenFundsNoticeView.onKeepHidden?()

        let key = CovHAssetListFixture.chainAsset().assetKey
        var model = ChainAssetListViewModel(displayState: .defaultList(cells: [], withAnimate: false), networkSections: [], walletId: "w")
        model.hiddenFundsNotice = PortfolioHiddenFundsNotice(assetKeys: [key], title: "1 hidden asset holds funds", message: "Review")
        controller.didReceive(viewModel: model)
        rootView.removeHeaderView()
        controller.reloadBanners()
        XCTAssertNotNil(rootView.tableView.tableHeaderView)

        rootView.exclusionsView.onTapHiddenAssets?()
        rootView.exclusionsView.onTapTestnetAssets?()
        rootView.hiddenFundsNoticeView.onReview?()
        rootView.hiddenFundsNoticeView.onKeepHidden?()
        rootView.tableView.refreshControl?.sendActions(for: .valueChanged)

        XCTAssertEqual(output.calls, ["load", "hiddenAssets", "testnetAssets", "reviewHidden", "keepHidden", "refresh"])
        XCTAssertEqual(output.keptHidden, [[key]])
    }

    func testManageAnimationRunsOnceAndReportsTheEnd() throws {
        let (controller, output) = try makeController()
        let rootView = controller.rootView
        // UIKit runs animation blocks and completions at once while animations are off; the busy host may never finish them.
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(true) }

        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .defaultList(cells: [], withAnimate: true), networkSections: [], walletId: "w"))
        XCTAssertTrue(rootView.isAnimating)
        controller.didReceive(viewModel: ChainAssetListViewModel(displayState: .defaultList(cells: [], withAnimate: true), networkSections: [], walletId: "w"))

        CovHAssetListFixture.spin(timeout: 6) { output.calls.contains("animationDone") }
        XCTAssertEqual(output.calls.filter { $0 == "animationDone" }.count, 1)
        XCTAssertFalse(rootView.isAnimating)
        XCTAssertEqual(rootView.footerButton.transform, .identity)
    }

    func testTokenLensExpandsGroupsAndTheZeroSummary() throws {
        let (controller, output) = try makeController()
        let tableView = controller.rootView.tableView
        let first = CovHAssetListFixture.chainAsset(id: "first", symbol: "FST")
        let second = CovHAssetListFixture.chainAsset(id: "second", symbol: "SND")
        let zero = CovHAssetListFixture.chainAsset(id: "zero", symbol: "ZRO")
        let group = CovHAssetListViews.row(
            id: "group:cov",
            children: [CovHAssetListViews.child(first, amount: 2), CovHAssetListViews.child(second, amount: 1)],
            zeroChildren: [CovHAssetListViews.child(zero, amount: 0)],
            single: false
        )
        let zeroRow = CovHAssetListViews.row(id: "asset:zero", children: [CovHAssetListViews.child(zero, amount: 0)], single: true)
        var model = ChainAssetListViewModel(displayState: .defaultList(cells: [], withAnimate: false), networkSections: [], walletId: "wallet-token")
        model.lens = .token
        model.tokenRows = [group]
        model.zeroTokenRows = [zeroRow]
        model.tokenChildCells = Dictionary(uniqueKeysWithValues: [first, second, zero].map {
            ($0.assetKey, CovHAssetListPresenterContext.cell(for: $0))
        })
        controller.didReceive(viewModel: model)

        XCTAssertEqual(controller.numberOfSections(in: tableView), 2)
        XCTAssertEqual(controller.tableView(tableView, numberOfRowsInSection: 1), 0)
        let header = try XCTUnwrap(controller.tableView(tableView, viewForHeaderInSection: 1) as? AssetNetworkHeaderView)
        header.onTap?()
        XCTAssertEqual(controller.tableView(tableView, numberOfRowsInSection: 1), 1)
        XCTAssertNil(controller.tableView(tableView, viewForHeaderInSection: 4))

        controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(controller.tableView(tableView, numberOfRowsInSection: 0), 4, "Token, two networks and the zero summary")
        let summary = controller.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: 0))
        XCTAssertEqual(summary.accessoryType, .disclosureIndicator)
        XCTAssertFalse(summary.textLabel?.text?.isEmpty ?? true)

        let groupCell = try XCTUnwrap(controller.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as? TokenGroupBalanceTableCell)
        groupCell.onAction?(.send)
        controller.swipeCellDidTap(on: .receive, with: IndexPath(row: 0, section: 0))
        controller.swipeCellDidTap(on: .receive, with: nil)
        XCTAssertEqual(output.tokenActions.map(\.1), ["group:cov", "group:cov"])

        let expandAction = try XCTUnwrap(groupCell.accessibilityCustomActions?.first)
        _ = expandAction.actionHandler?(expandAction)
        XCTAssertEqual(controller.tableView(tableView, numberOfRowsInSection: 0), 1, "The accessibility action collapses the group")

        controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 7))
        XCTAssertFalse(output.calls.contains("select"))
    }

    func testEmptyWalletSummariesAndNetworkHeaders() throws {
        let (controller, output) = try makeController()
        let tableView = controller.rootView.tableView
        let asset = CovHAssetListFixture.chainAsset()
        let cell = CovHAssetListPresenterContext.cell(for: asset)
        var tokenModel = ChainAssetListViewModel(displayState: .defaultList(cells: [], withAnimate: false), networkSections: [], walletId: "empty")
        tokenModel.lens = .token
        tokenModel.isWalletEmpty = true
        tokenModel.zeroTokenRows = [CovHAssetListViews.row(id: "asset:z", children: [CovHAssetListViews.child(asset, amount: 0)], single: true)]
        tokenModel.tokenRows = [CovHAssetListViews.row(id: "asset:a", children: [CovHAssetListViews.child(asset, amount: 1)], single: true)]
        tokenModel.tokenChildCells = [asset.assetKey: cell]
        controller.didReceive(viewModel: tokenModel)
        let emptyHeader = try XCTUnwrap(controller.tableView(tableView, viewForHeaderInSection: 1) as? AssetNetworkHeaderView)
        XCTAssertFalse(emptyHeader.accessibilityLabel?.isEmpty ?? true)

        var networkModel = ChainAssetListViewModel(
            displayState: .defaultList(cells: [cell], withAnimate: false),
            networkSections: [
                CovHAssetListViews.section(id: "portfolio:zero-networks", kind: .zeroNetworks(count: 1), rows: []),
                CovHAssetListViews.section(id: "zero-child", kind: .assets, rows: [cell], parent: "portfolio:zero-networks")
            ],
            walletId: "empty"
        )
        networkModel.lens = .network
        networkModel.isWalletEmpty = true
        controller.didReceive(viewModel: networkModel)
        XCTAssertEqual(controller.numberOfSections(in: tableView), 1, "The empty networks stay folded")
        let summary = try XCTUnwrap(controller.tableView(tableView, viewForHeaderInSection: 0) as? AssetNetworkHeaderView)
        XCTAssertEqual(summary.accessibilityValue, PortfolioStrings.text("ux.collapsed", locale: Locale(identifier: "en")))
        summary.perform(NSSelectorFromString("didTap"))
        XCTAssertEqual(controller.numberOfSections(in: tableView), 2)

        let plain = ChainAssetListViewModel(displayState: .defaultList(cells: [cell], withAnimate: false), networkSections: [], walletId: "empty", lens: .network)
        controller.didReceive(viewModel: plain)
        controller.tableView(tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(output.selected.map(\.chainAsset.assetKey), [asset.assetKey])
    }

    func testLayoutEmptyStatesAndFooterTitles() {
        let layout = ChainAssetListViewLayout()
        layout.locale = Locale(identifier: "en")
        let languages = Locale(identifier: "en").rLanguages
        let chain = CovHAssetListFixture.chain()
        let states: [(AssetListState, String?)] = [
            (.defaultList(cells: [], withAnimate: false), nil),
            (.allIsHidden, R.string.localizable.walletAllAssetsHidden(preferredLanguages: languages)),
            (.chainHasNetworkIssue(chain: chain), "Connection Error: Unable to connect to the network. Please try again."),
            (.chainHasAccountIssue(chain: chain), R.string.localizable.accountNeededMessage(preferredLanguages: languages)),
            (.search(cells: []), R.string.localizable.emptyViewDescription(preferredLanguages: languages))
        ]
        for (state, text) in states {
            let container = layout.viewForEmptyState(for: state)
            let empty = CovHAssetListViews.find(EmptyView.self, in: container).first
            XCTAssertEqual(empty?.text, text)
            XCTAssertEqual(empty?.title, R.string.localizable.emptyViewTitle(preferredLanguages: languages))
        }

        layout.setFooterButtonTitle(for: .allIsHidden)
        XCTAssertEqual(layout.footerButton.title(for: .normal), R.string.localizable.walletManageAssets(preferredLanguages: languages))
        layout.setFooterView()
        XCTAssertNotNil(layout.tableView.tableFooterView)
        layout.removeFooterView()
        XCTAssertNil(layout.tableView.tableFooterView)
        XCTAssertNil(layout.footerButton.superview)

        let banners = UIView()
        layout.addBanners(view: banners)
        XCTAssertTrue(layout.bannersView === banners)
        XCTAssertTrue(banners.isHidden)
    }

    func testBalanceCellShowsAndClearsNetworkOptions() {
        let cell = ChainAccountBalanceTableCell(style: .default, reuseIdentifier: nil)
        let options = [ChainOptionsViewModel(text: "testnet", icon: nil), ChainOptionsViewModel(text: "crowdloans", icon: nil)]
        cell.bind(to: CovHAssetListPresenterContext.cell(for: CovHAssetListFixture.chainAsset(), options: options))
        XCTAssertEqual(CovHAssetListViews.find(ChainOptionsView.self, in: cell).count, 2)

        cell.prepareForReuse()
        XCTAssertEqual(CovHAssetListViews.find(ChainOptionsView.self, in: cell).count, 0)
    }

    func testActionButtonReturnsToRestAfterAPress() {
        let button = PortfolioActionButton()
        button.sendActions(for: .touchDown)
        button.sendActions(for: .touchUpInside)
        XCTAssertEqual(button.transform, .identity)
    }
}
