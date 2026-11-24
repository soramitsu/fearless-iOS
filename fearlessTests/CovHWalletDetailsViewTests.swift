import XCTest
import UIKit
import SSFModels
@testable import fearless

final class CovHWalletDetailsViewOutputSpy: WalletDetailsViewOutputProtocol {
    var calls: [String] = []
    var loadedViews: [WalletDetailsViewProtocol] = []
    var searches: [String?] = []
    var actionChains: [ChainModel] = []
    var actionAccounts: [ChainAccountResponse?] = []

    func didLoad(ui: WalletDetailsViewProtocol) { calls.append("load"); loadedViews.append(ui) }
    func didTapCloseButton() { calls.append("close") }
    func didTapExportButton() { calls.append("export") }
    func showActions(for chain: ChainModel, account: ChainAccountResponse?) {
        calls.append("actions"); actionChains.append(chain); actionAccounts.append(account)
    }

    func searchTextDidChanged(_ text: String?) { calls.append("search"); searches.append(text) }
}

final class CovHWalletDetailsCellDelegateSpy: WalletDetailsTableCellDelegate {
    var tapped: [WalletDetailsTableCell] = []
    func didTapActions(_ cell: WalletDetailsTableCell) { tapped.append(cell) }
}

final class CovHWalletDetailsViewTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        super.tearDown()
    }

    private func makeController() -> (WalletDetailsViewController, CovHWalletDetailsViewOutputSpy) {
        let output = CovHWalletDetailsViewOutputSpy()
        let controller = WalletDetailsViewController(output: output)
        window = CovHChainAccountViewInspector.host(controller)
        return (controller, output)
    }

    private func sections(wallet: MetaAccountModel) -> [WalletDetailsSection] {
        let first = CovHChainAccountFixture.chain(name: "First chain")
        let second = CovHChainAccountFixture.chain(name: "Second chain")
        let account = CovHWalletDetailsFixture.chainAccountResponse(for: first, wallet: wallet, isChainAccount: false)
        return [
            WalletDetailsSection(title: "shared", viewModels: [
                CovHWalletDetailsFixture.cell(chain: first, account: account),
                CovHWalletDetailsFixture.cell(chain: second, account: nil, address: nil, missing: true)
            ]),
            WalletDetailsSection(title: "custom", viewModels: [CovHWalletDetailsFixture.cell(chain: second, account: nil)])
        ]
    }

    func testLoadWiresButtonsAndSearch() {
        let (controller, output) = makeController()
        XCTAssertEqual(output.calls, ["load"])
        XCTAssertTrue(output.loadedViews.first === controller)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.exportButton.sendActions(for: .touchUpInside)
        controller.rootView.searchTextField.onTextDidChanged?("dot")
        XCTAssertEqual(output.calls, ["load", "close", "export", "search"])
        XCTAssertEqual(output.searches, ["dot"])
        XCTAssertEqual(controller.numberOfSections(in: controller.rootView.tableView), 0)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertNil(controller.tableView(controller.rootView.tableView, viewForHeaderInSection: 0))
    }

    func testNormalStateFillsTableAndRoutesActions() throws {
        let (controller, output) = makeController()
        let wallet = CovHChainAccountFixture.wallet()
        let sections = sections(wallet: wallet)
        controller.didReceive(state: .normal(viewModel: CovHWalletDetailsFixture.normalModel(sections: sections)))
        let table = controller.rootView.tableView
        table.layoutIfNeeded()
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 1), 1)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: IndexPath(row: 0, section: 0)), 72)
        let header = try XCTUnwrap(controller.tableView(table, viewForHeaderInSection: 1) as? WalletDetailsTableHeaderView)
        XCTAssertTrue(CovHChainAccountViewInspector.texts(in: header).contains("CUSTOM"))
        XCTAssertFalse(controller.shouldDisplayEmptyState)
        XCTAssertEqual(controller.rootView.navigationLabel.text, "Details")
        XCTAssertTrue(controller.rootView.exportButton.isHidden)

        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? WalletDetailsTableCell)
        XCTAssertTrue(CovHChainAccountViewInspector.texts(in: cell).contains("First chain"))
        controller.didTapActions(cell)
        XCTAssertEqual(output.actionChains.map(\.name), ["First chain"])
        XCTAssertEqual(output.actionAccounts.first??.accountId, sections[0].viewModels[0].account?.accountId)

        controller.didTapActions(WalletDetailsTableCell(style: .default, reuseIdentifier: nil))
        XCTAssertEqual(output.actionChains.count, 1, "a cell outside the table has no row")
    }

    func testExportStateShowsExportButtonAndIgnoresActions() throws {
        let (controller, output) = makeController()
        let sections = sections(wallet: CovHChainAccountFixture.wallet())
        controller.didReceive(state: .export(viewModel: CovHWalletDetailsFixture.exportModel(sections: sections)))
        let table = controller.rootView.tableView
        table.layoutIfNeeded()
        XCTAssertFalse(controller.rootView.exportButton.isHidden)
        XCTAssertEqual(controller.rootView.navigationLabel.text, "Export")
        XCTAssertEqual(controller.numberOfSections(in: table), 2)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertNotNil(controller.tableView(table, viewForHeaderInSection: 0) as? WalletDetailsTableHeaderView)
        let expectedInset = UIConstants.actionHeight + UIConstants.bigOffset * 2
        XCTAssertEqual(table.contentInset.bottom, expectedInset)
        let cell = try XCTUnwrap(table.cellForRow(at: IndexPath(row: 0, section: 0)) as? WalletDetailsTableCell)
        controller.didTapActions(cell)
        XCTAssertTrue(output.actionChains.isEmpty)
        XCTAssertFalse(controller.shouldDisplayEmptyState)
    }

    func testEmptyStateLocaleAndKeyboardHandling() throws {
        let (controller, _) = makeController()
        controller.didReceive(state: .normal(viewModel: CovHWalletDetailsFixture.normalModel(sections: [])))
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        controller.didReceive(state: .export(viewModel: CovHWalletDetailsFixture.exportModel(sections: [])))
        XCTAssertTrue(controller.shouldDisplayEmptyState)
        let empty = try XCTUnwrap(controller.viewForEmptyState as? EmptyView)
        XCTAssertNotNil(empty.image)
        XCTAssertTrue(controller.contentViewForEmptyState === controller.rootView.container)
        XCTAssertTrue(controller.emptyStateDelegate === controller)

        let locale = Locale(identifier: "en")
        controller.didReceive(locale: locale)
        XCTAssertEqual(
            controller.rootView.searchTextField.textField.placeholder,
            R.string.localizable.selectNetworkSearchPlaceholder(preferredLanguages: locale.rLanguages)
        )
        XCTAssertTrue(controller.target === controller.rootView.keyboardAdoptableConstraint)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(40), 0)
        controller.updateWhileKeyboardFrameChanging(.zero)
        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)
    }

    func testCellBindsSupportedMissingAndUnsupportedChains() throws {
        let wallet = CovHChainAccountFixture.wallet()
        let supported = CovHChainAccountFixture.chain(name: "Supported")
        let delegate = CovHWalletDetailsCellDelegateSpy()
        let cell = WalletDetailsTableCell(style: .default, reuseIdentifier: nil)
        cell.delegate = delegate
        let account = CovHWalletDetailsFixture.chainAccountResponse(for: supported, wallet: wallet, isChainAccount: false)
        cell.bind(to: CovHWalletDetailsFixture.cell(chain: supported, account: account, address: "addr-1"))
        var texts = CovHChainAccountViewInspector.texts(in: cell)
        XCTAssertTrue(texts.contains("Supported"))
        XCTAssertTrue(texts.contains("addr-1"))
        XCTAssertEqual(cell.deactivatableViews.first?.alpha, supported.isSupported ? 1 : 0.5)

        cell.prepareForReuse()
        cell.bind(to: CovHWalletDetailsFixture.cell(chain: supported, account: nil, address: nil, missing: true))
        texts = CovHChainAccountViewInspector.texts(in: cell)
        XCTAssertTrue(texts.contains(R.string.localizable.noAccountFound(preferredLanguages: ["en"])))
        XCTAssertEqual(cell.deactivatableViews.first?.alpha, 0.5)
        XCTAssertEqual(cell.deactivatedAlpha, 0.5)

        let unsupported = CovHChainAccountFixture.chain(name: "Future", minAppVersion: "999.0.0")
        cell.bind(to: CovHWalletDetailsFixture.cell(chain: unsupported, account: account))
        XCTAssertFalse(unsupported.isSupported)
        XCTAssertEqual(cell.deactivatableViews.first?.alpha, 0.5)
        XCTAssertTrue(CovHChainAccountViewInspector.texts(in: cell).contains(R.string.localizable.commonUnsupported(preferredLanguages: ["en"])))

        cell.perform(NSSelectorFromString("showActions"))
        XCTAssertTrue(delegate.tapped.first === cell)
    }

    func testHeaderUppercasesItsTitle() {
        let header = WalletDetailsTableHeaderView(reuseIdentifier: nil)
        header.setTitle(text: "Chain accounts")
        XCTAssertTrue(CovHChainAccountViewInspector.texts(in: header).contains("CHAIN ACCOUNTS"))
    }

    func testFactoryBuildsTheScreenForTheFlow() throws {
        let view = WalletDetailsViewFactory.createView(flow: .normal(wallet: CovHChainAccountFixture.wallet()))
        let controller = try XCTUnwrap(view as? WalletDetailsViewController)
        XCTAssertTrue(controller.output is WalletDetailsPresenter)
    }
}
