import RobinHood
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

/// The history sheet: table updates, row selection, the draggable sheet states, the hidden header type and the cell.
final class CovHTxHistoryViewTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func makeController(hosted: Bool = true) -> (WalletTransactionHistoryViewController, CovHTxHistoryPresenterSpy) {
        let presenter = CovHTxHistoryPresenterSpy()
        let controller = WalletTransactionHistoryViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        if hosted {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = controller
            window.makeKeyAndVisible()
            self.window = window
        }
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        return (controller, presenter)
    }

    private func viewModel(
        _ sections: [WalletTransactionHistorySection],
        changes: [WalletTransactionHistoryChange],
        filtering: WalletTransactionHistoryViewFilterMode = .multiple
    ) -> WalletTransactionHistoryViewModel {
        WalletTransactionHistoryViewModel(sections: sections, lastChanges: changes, filtering: filtering)
    }

    func testSectionAndRowChangesAreAppliedToTheTable() throws {
        let (controller, presenter) = makeController()
        XCTAssertTrue(presenter.view === controller)
        let table = controller.rootView.tableView
        table.reloadData()
        table.layoutIfNeeded()
        XCTAssertEqual(table.numberOfSections, 0)

        let section = WalletTransactionHistorySection(title: "Today", items: [CovHTxHistoryFixture.cell("a"), CovHTxHistoryFixture.cell("b")])
        controller.didReceive(state: .loaded(viewModel: viewModel([section], changes: [.insert(index: 0, newSection: section)])))
        XCTAssertEqual(table.numberOfSections, 1)
        XCTAssertEqual(table.numberOfRows(inSection: 0), 2)
        XCTAssertFalse(table.isHidden)
        XCTAssertFalse(controller.rootView.filterButton.isHidden)
        XCTAssertFalse(controller.rootView.separatorView.isHidden)
        let callsBeforeScroll = presenter.loadNextCalls
        table.contentOffset = CGPoint(x: 0, y: table.contentSize.height + 1)
        controller.scrollViewDidScroll(table)
        XCTAssertGreaterThan(presenter.loadNextCalls, callsBeforeScroll, "Scrolling past the end asks for the next page")

        let added = CovHTxHistoryFixture.cell("c", status: .pending)
        section.items.append(added)
        controller.didReceive(state: .loaded(viewModel: viewModel(
            [section], changes: [.update(index: 0, itemChange: .insert(index: 2, new: added), section: section)]
        )))
        XCTAssertEqual(table.numberOfRows(inSection: 0), 3)

        controller.didReceive(state: .loaded(viewModel: viewModel(
            [section], changes: [.update(index: 0, itemChange: .update(index: 0, old: section.items[0], new: section.items[0]), section: section)]
        )))
        XCTAssertEqual(table.numberOfRows(inSection: 0), 3)

        let removed = section.items.removeLast()
        controller.didReceive(state: .loaded(viewModel: viewModel(
            [section], changes: [.update(index: 0, itemChange: .delete(index: 2, old: removed), section: section)]
        )))
        XCTAssertEqual(table.numberOfRows(inSection: 0), 2)
        table.contentOffset = .zero
        controller.view.layoutIfNeeded()
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? WalletTransactionHistoryCell)
        XCTAssertNotNil(cell)

        XCTAssertTrue(controller.tableView(table, viewForHeaderInSection: 0) is WalletTransactionHistoryTableSectionHeader)
        XCTAssertEqual(controller.tableView(table, heightForHeaderInSection: 0), 20)
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.selected.map(\.transaction.transactionId), ["b"])

        controller.didReceive(state: .loaded(viewModel: viewModel([], changes: [.delete(index: 0, oldSection: section)], filtering: .disabled)))
        XCTAssertEqual(table.numberOfSections, 0)
        XCTAssertTrue(table.isHidden)
        XCTAssertTrue(controller.rootView.filterButton.isHidden)
        XCTAssertEqual(
            controller.titleForEmptyState,
            R.string.localizable.walletTransactionHistoryEmptyMessage(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        )
        XCTAssertTrue(controller.shouldDisplayEmptyState)
    }

    func testWithoutLoadedRowsTheTableShowsNothingAndIgnoresSelection() {
        let (controller, presenter) = makeController(hosted: false)
        let table = controller.rootView.tableView
        controller.didReceive(state: .loading)
        XCTAssertTrue(table.isHidden)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 0)
        XCTAssertFalse(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) is WalletTransactionHistoryCell)
        XCTAssertNil(controller.tableView(table, viewForHeaderInSection: 0))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(presenter.selected.isEmpty)
        XCTAssertFalse(controller.shouldDisplayEmptyState)

        controller.rootView.filterButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.filterTaps, 1)

        controller.scrollViewDidScroll(table)
        XCTAssertTrue(table.bounces)
        XCTAssertTrue(table.showsVerticalScrollIndicator)
        XCTAssertIdentical(controller.draggableView, controller.view)
        XCTAssertIdentical(controller.scrollPanRecognizer, table.panGestureRecognizer)
    }

    func testBarSheetMovesBetweenCompactAndFull() {
        let (controller, _) = makeController()
        let delegate = CovHTxHistoryDraggableDelegate()
        controller.delegate = delegate
        let layout = controller.rootView
        let table = layout.tableView

        XCTAssertTrue(controller.canDrag(from: .compact))
        XCTAssertTrue(controller.canDrag(from: .full))
        table.contentOffset = CGPoint(x: 0, y: 10)
        XCTAssertFalse(controller.canDrag(from: .full))
        table.contentOffset = .zero

        controller.set(contentInsets: UIEdgeInsets(top: 0, left: 0, bottom: 33, right: 0), for: .compact)
        XCTAssertEqual(table.contentInset.bottom, 33)
        controller.set(contentInsets: UIEdgeInsets(top: 80, left: 0, bottom: 44, right: 0), for: .full)
        XCTAssertEqual(table.contentInset.bottom, 33, "Insets of the other state wait for that state")

        controller.set(dragableState: .full, animated: false)
        XCTAssertFalse(layout.closeButton.isHidden)
        XCTAssertTrue(table.isScrollEnabled)
        XCTAssertEqual(layout.closeButton.alpha, 1, accuracy: 0.001)
        layout.closeButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.transits, [.compact])

        controller.animate(progress: 0.5, from: .full, to: .compact, finalFrame: controller.view.frame)
        XCTAssertFalse(table.isScrollEnabled, "A sheet on its way down stops scrolling")
        XCTAssertEqual(layout.panIndicatorView.alpha, 1, accuracy: 0.001)

        controller.set(dragableState: .compact, animated: true)
        XCTAssertTrue(layout.closeButton.isHidden)
        XCTAssertFalse(table.showsVerticalScrollIndicator)
        layout.closeButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(delegate.transits, [.compact], "Closing only acts on a full sheet")

        controller.setEmbeddedInColumns(true)
        XCTAssertTrue(layout.panIndicatorView.isHidden)
        XCTAssertTrue(layout.closeButton.isHidden)
    }

    func testHiddenHeaderSheetTakesOverTheNavigationItemAndGivesItBack() {
        let (controller, _) = makeController()
        let delegate = CovHTxHistoryDraggableDelegate()
        controller.delegate = delegate
        controller.headerType = .hidden
        let item = delegate.navigationItem

        controller.set(dragableState: .full, animated: false)
        XCTAssertEqual(item.title, L10n.History.title)
        XCTAssertNotNil(item.leftBarButtonItem)
        XCTAssertNotNil(item.rightBarButtonItem)
        XCTAssertEqual(controller.rootView.headerView.alpha, 0, accuracy: 0.001)

        controller.applyLocalization()
        XCTAssertEqual(item.title, L10n.History.title)

        controller.animate(progress: 0.5, from: .full, to: .compact, finalFrame: controller.view.frame)
        XCTAssertEqual(controller.rootView.headerView.alpha, 1, accuracy: 0.001)

        controller.set(dragableState: .compact, animated: false)
        XCTAssertEqual(item.title, "Before")
        XCTAssertNil(item.leftBarButtonItem)
        XCTAssertNil(item.rightBarButtonItem)
    }

    func testCellBindsRemoteIconsPendingRingAndReuse() {
        let cell = WalletTransactionHistoryCell(style: .default, reuseIdentifier: nil)
        cell.bind(to: CovHTxHistoryFixture.cell("pending", status: .pending))
        XCTAssertEqual(cell.transactionAmountLabel.textColor, R.color.colorWhite16())
        XCTAssertTrue(cell.transactionStatusIconImageView.isHidden)
        XCTAssertEqual(cell.addressLabel.text, "peer-pending")

        cell.prepareForReuse()
        let icon = UIImage()
        cell.bind(to: CovHTxHistoryFixture.cell("done", status: .commited, icon: icon))
        XCTAssertIdentical(cell.accountIconImageView.image, icon)
        XCTAssertEqual(cell.transactionAmountLabel.textColor, R.color.colorWhite())
    }
}
