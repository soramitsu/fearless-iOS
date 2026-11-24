import XCTest
import UIKit
@testable import fearless

/// Implements everything except `presentResetOrderConfirmation`, so the protocol's default applies.
final class CovJMxAssetRouterStub: CovJSheetSpy, AssetManagementRouterInput {
    var networkSelections = 0
    var dismissals = 0
    func showSelectNetwork(from _: ControllerBackedProtocol?, wallet _: MetaAccountModel, delegate _: NetworkManagmentModuleOutput?) {
        networkSelections += 1
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
}

final class CovJMxAssetHostView: UIViewController, ControllerBackedProtocol {}

final class CovJMxAssetManagementTests: XCTestCase {
    func testVisibilityFilterKeepsMatchingRowsAndDropsEmptySections() {
        let shown = cell(symbol: "AAA", hidden: false, preference: .shown)
        let hidden = cell(symbol: "BBB", hidden: true, preference: .hidden)
        let auto = cell(symbol: "CCC", hidden: false, preference: .auto)
        let autoHidden = cell(symbol: "DDD", hidden: true, preference: .auto)
        let viewModel = AssetManagementViewModel(
            list: [section(id: "one", cells: [shown, hidden]), section(id: "two", cells: [auto, autoHidden])],
            filterButtonTitle: "All",
            addAssetButtonIsHidden: true,
            dispayedChainAssets: []
        )

        let all = viewModel.filtered(by: .all)
        XCTAssertEqual(all.visibilityFilter, .all)
        XCTAssertEqual(all.list.map(\.id), ["one", "two"])
        XCTAssertEqual(all.dispayedChainAssets.map(\.asset.symbol), ["AAA", "BBB", "CCC", "DDD"])

        let visible = viewModel.filtered(by: .shown)
        XCTAssertEqual(visible.dispayedChainAssets.map(\.asset.symbol), ["AAA", "CCC"])

        let hiddenOnly = viewModel.filtered(by: .hidden)
        XCTAssertEqual(hiddenOnly.list.map(\.id), ["one"])
        XCTAssertEqual(hiddenOnly.dispayedChainAssets.map(\.asset.symbol), ["BBB"])

        let automatic = viewModel.filtered(by: .auto)
        XCTAssertEqual(automatic.list.map(\.id), ["two"])
        XCTAssertEqual(automatic.dispayedChainAssets.map(\.asset.symbol), ["CCC", "DDD"])
        XCTAssertEqual(automatic.filterButtonTitle, "All")
        XCTAssertEqual(ManageAssetsFilter.allCases, [.all, .shown, .hidden, .auto])
    }

    func testRouterPresentsOnlyAWellFormedResetConfirmationOnAnIdleScreen() throws {
        let host = CovJMxAssetHostView()
        let window = try CovJViewFixture.host(host)
        defer {
            host.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let router = AssetManagementRouter()
        let confirm = SheetAlertPresentableAction(title: "Reset")
        let valid = SheetAlertPresentableViewModel(title: "Reset order?", message: "Order", actions: [confirm], closeAction: "Cancel")

        router.presentResetOrderConfirmation(viewModel: valid, from: nil)
        router.presentResetOrderConfirmation(
            viewModel: SheetAlertPresentableViewModel(title: "x", message: nil, actions: [confirm, confirm], closeAction: "Cancel"),
            from: host
        )
        router.presentResetOrderConfirmation(
            viewModel: SheetAlertPresentableViewModel(title: "x", message: nil, actions: [confirm], closeAction: nil),
            from: host
        )
        XCTAssertNil(host.presentedViewController)

        router.presentResetOrderConfirmation(viewModel: valid, from: host)
        let presented = try XCTUnwrap(host.presentedViewController as? AssetManagementResetOrderViewController)
        XCTAssertEqual(presented.modalPresentationStyle, .overFullScreen)

        router.presentResetOrderConfirmation(viewModel: valid, from: host)
        XCTAssertTrue(host.presentedViewController === presented)
        XCTAssertTrue(CovJWait.until(timeout: 3) { !presented.isBeingPresented })
    }

    func testRouterProtocolDefaultFallsBackToTheStandardSheet() {
        let router = CovJMxAssetRouterStub()
        let viewModel = SheetAlertPresentableViewModel(title: "Reset order?", message: nil, actions: [], closeAction: nil)

        router.presentResetOrderConfirmation(viewModel: viewModel, from: nil)

        XCTAssertEqual(router.sheets.map(\.title), ["Reset order?"])
        XCTAssertEqual(router.networkSelections, 0)
    }

    // MARK: - Fixtures

    private func cell(symbol: String, hidden: Bool, preference: AssetPreference) -> AssetManagementTableCellViewModel {
        AssetManagementTableCellViewModel(
            chainAsset: CovJFixture.chainAsset(chainName: "Chain\(symbol)", symbol: symbol),
            assetImage: nil,
            assetName: symbol,
            chainName: "Chain\(symbol)",
            balance: BalanceViewModel(amount: "1", price: nil),
            decimalPrice: 1,
            hidden: hidden,
            hasGroup: false,
            isLoadingBalance: false,
            preference: preference
        )
    }

    private func section(id: String, cells: [AssetManagementTableCellViewModel]) -> AssetManagementTableSection {
        AssetManagementTableSection(
            hasView: true,
            assetImage: nil,
            assetName: id,
            assetCount: "\(cells.count)",
            isExpanded: true,
            cells: cells,
            isAllDisabled: false,
            totalBalance: 0,
            totalFiatBalance: 0,
            rank: 0,
            id: id
        )
    }
}
