import XCTest
import UIKit
import SoraFoundation
import FearlessWalletConnect
@testable import fearless

final class CovJWalletConnectProposalOutput: WalletConnectProposalViewOutput {
    var loaded = 0
    var disappeared = 0
    var back = 0
    var main = 0
    var rejected = 0
    var selected: [IndexPath] = []

    func didLoad(view: WalletConnectProposalViewInput) { loaded += 1 }
    func viewDidDisappear() { disappeared += 1 }
    func backButtonDidTapped() { back += 1 }
    func mainActionButtonDidTapped() { main += 1 }
    func rejectButtonDidTapped() { rejected += 1 }
    func didSelectRowAt(_ indexPath: IndexPath) { selected.append(indexPath) }
}

final class CovJWalletConnectProposalViewsTests: XCTestCase {
    func testProposalRendersEachCellAndRoutesActions() throws {
        let output = CovJWalletConnectProposalOutput()
        let controller = WalletConnectProposalViewController(
            status: .proposal(CovJWalletConnectFixture.proposal()), output: output,
            localizationManager: LocalizationManager.shared
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.applyLocalization()
        let table = controller.rootView.tableView
        XCTAssertEqual(output.loaded, 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        let details = WalletConnectProposalCellModel.DetailsViewModel(title: "App", subtitle: "example.invalid", icon: nil)
        let expandable = WalletConnectProposalCellModel.ExpandableViewModel(
            cellTitle: "Permissions", chain: "Ethereum", methods: "personal_sign", events: "accountsChanged", isExpanded: false
        )
        let cells: [WalletConnectProposalCellModel] = [
            .dAppInfo(details), .requiredNetworks(details), .optionalNetworks(details),
            .requiredExpandable(expandable), .optionalExpandable(expandable.toggle()),
            .wallet(.init(metaId: "wallet", walletName: "Savings", isSelected: true))
        ]
        controller.didReceive(viewModel: .init(indexPath: nil, cells: cells, expiryDate: nil))
        table.layoutIfNeeded()
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 6)
        XCTAssertTrue(controller.rootView.mainActionButton.isEnabled)
        for row in 0..<3 {
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: row, section: 0)) as? WalletConnectProposalDetailsTableCell)
            XCTAssertEqual(cell.view.title, "App")
            XCTAssertEqual(cell.view.subtitle, "example.invalid")
            XCTAssertEqual(cell.dropTriangleImageView.isHidden, row != 2)
            controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: row, section: 0))
        }
        for row in 3..<5 {
            let indexPath = IndexPath(row: row, section: 0)
            let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: indexPath) as? WalletConnectProposalExpandableTableCell)
            XCTAssertEqual(cell.methodsLabel.text, "personal_sign")
            XCTAssertEqual(cell.eventsLabel.text, "accountsChanged")
            XCTAssertEqual(cell.expandableBackground.isHidden, row == 3)
            XCTAssertEqual(controller.tableView(table, heightForRowAt: indexPath), row == 3 ? UIConstants.cellHeight : UITableView.automaticDimension)
        }
        let walletIndex = IndexPath(row: 5, section: 0)
        let walletCell = try XCTUnwrap(controller.tableView(table, cellForRowAt: walletIndex) as? WalletConnectProposalWalletsTableCell)
        controller.tableView(table, willDisplay: walletCell, forRowAt: walletIndex)
        XCTAssertEqual(walletCell.view.title, "Savings")
        XCTAssertEqual(controller.tableView(table, heightForRowAt: walletIndex), UITableView.automaticDimension)
        controller.tableView(table, didSelectRowAt: walletIndex)
        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        controller.rootView.mainActionButton.sendActions(for: .touchUpInside)
        controller.rootView.rejectButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(output.selected, [walletIndex])
        XCTAssertEqual(output.back, 1)
        XCTAssertEqual(output.main, 1)
        XCTAssertEqual(output.rejected, 1)
        var updated = cells
        updated[5] = .wallet(.init(metaId: "wallet", walletName: "Savings", isSelected: false))
        controller.didReceive(viewModel: .init(indexPath: walletIndex, cells: updated, expiryDate: nil))
        XCTAssertFalse(controller.rootView.mainActionButton.isEnabled)
        let invalid = IndexPath(row: 99, section: 0)
        XCTAssertEqual(controller.tableView(table, heightForRowAt: invalid), UITableView.automaticDimension)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: invalid) is WalletConnectProposalWalletsTableCell)
    }

    func testActiveSessionShowsExpiryAndDisconnectWithoutReject() throws {
        let output = CovJWalletConnectProposalOutput()
        let controller = WalletConnectProposalViewController(
            status: .active(CovJWalletConnectFixture.session()), output: output,
            localizationManager: LocalizationManager.shared
        )
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.rootView.locale = CovJWalletConnectFixture.locale
        controller.didReceive(viewModel: .init(indexPath: nil, cells: [], expiryDate: "30 November 2026"))
        XCTAssertTrue(controller.rootView.mainActionButton.isEnabled)
        XCTAssertNil(controller.rootView.rejectButton.superview)
        XCTAssertTrue(controller.rootView.tableView.tableFooterView === controller.rootView.expiryDateView)
        XCTAssertEqual(controller.rootView.expiryDateView.valueLabel.text, "30 November 2026")
        XCTAssertEqual(controller.rootView.expiryDateView.frame.height, UIConstants.cellHeight)
        XCTAssertEqual(controller.rootView.mainActionButton.imageWithTitleView?.title,
                       R.string.localizable.commonDisconnect(preferredLanguages: CovJWalletConnectFixture.locale.rLanguages))
        controller.viewDidDisappear(false)
        XCTAssertEqual(output.disappeared, 1)
        controller.rootView.setExpiryDate(string: nil)
        XCTAssertEqual(controller.rootView.expiryDateView.valueLabel.text, "30 November 2026")
    }

    func testExpandableCellHidesEmptyEventsAndRestoresExpandedContent() {
        let cell = WalletConnectProposalExpandableTableCell(style: .default, reuseIdentifier: nil)
        cell.locale = CovJWalletConnectFixture.locale
        cell.bind(viewModel: .init(cellTitle: "Required", chain: "Ethereum", methods: "personal_sign", events: "", isExpanded: false))
        XCTAssertEqual(cell.visibleTitle.text, "Required")
        XCTAssertEqual(cell.chainNameLabel.text, "Ethereum")
        XCTAssertTrue(cell.eventsLabel.isHidden)
        XCTAssertTrue(cell.eventsTitleLabel.isHidden)
        XCTAssertTrue(cell.expandableBackground.isHidden)
        XCTAssertEqual(cell.expandableAccesoryImageView.image, R.image.basicPlus())
        cell.bind(viewModel: .init(cellTitle: "Optional", chain: "Polygon", methods: "eth_sendTransaction", events: "chainChanged", isExpanded: true))
        XCTAssertEqual(cell.visibleTitle.text, "Optional")
        XCTAssertEqual(cell.methodsLabel.text, "eth_sendTransaction")
        XCTAssertEqual(cell.eventsLabel.text, "chainChanged")
        XCTAssertFalse(cell.eventsLabel.isHidden)
        XCTAssertFalse(cell.eventsTitleLabel.isHidden)
        XCTAssertFalse(cell.expandableBackground.isHidden)
        XCTAssertEqual(cell.expandableAccesoryImageView.image, R.image.basicMinus())
        XCTAssertEqual(cell.methodsTitleLabel.text, R.string.localizable.commonMethods(preferredLanguages: CovJWalletConnectFixture.locale.rLanguages))
    }

    func testDetailsCellResetsReuseInsetsAndAcceptsIconModel() {
        let cell = WalletConnectProposalDetailsTableCell(style: .default, reuseIdentifier: nil)
        cell.dropTriangleImageView.isHidden = false
        cell.bind(viewModel: .init(title: "Networks", subtitle: "Ethereum", icon: RemoteImageViewModel(string: nil)))
        XCTAssertEqual(cell.view.title, "Networks")
        XCTAssertEqual(cell.view.subtitle, "Ethereum")
        XCTAssertEqual(cell.view.contentInsets.right, UIConstants.bigOffset * 2)
        cell.prepareForReuse()
        XCTAssertNil(cell.view.iconImage)
        XCTAssertEqual(cell.view.contentInsets, UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
        cell.dropTriangleImageView.isHidden = true
        cell.bind(viewModel: .init(title: "Optional", subtitle: "Polygon", icon: nil))
        XCTAssertEqual(cell.view.title, "Optional")
        XCTAssertEqual(cell.view.subtitle, "Polygon")
        XCTAssertEqual(cell.view.contentInsets.right, 8)
    }
}
