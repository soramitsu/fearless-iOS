@testable import fearless
import SoraFoundation
import UIKit
import XCTest

/// The important-flow navigation controller: close button when presented, dismissal veto for important screens and
/// the cancel-operation sheet.
@MainActor
final class CovENavigationTests: XCTestCase {
    func testPresentedImportantFlowAddsCloseButtonAndVetoesDismissal() throws {
        let host = UIViewController()
        let window = CovEHost.window(for: host)
        defer { CovEHost.close(window) }
        let root = CovEImportantScreen()
        let navigation = try XCTUnwrap(ImportantFlowViewFactory.createNavigation(from: root) as? ImportantFlowNavigationController)
        XCTAssertEqual(navigation.viewControllers, [root])
        host.present(navigation, animated: false)
        XCTAssertTrue(CovEHost.spin(until: { host.presentedViewController === navigation }))
        navigation.view.layoutIfNeeded()
        XCTAssertTrue(navigation.presentationController?.delegate === navigation)
        XCTAssertTrue(navigation.childForStatusBarStyle === root)

        XCTAssertTrue(CovEHost.spin(until: { root.navigationItem.leftBarButtonItem?.customView != nil }))
        let closeItem = try XCTUnwrap(root.navigationItem.leftBarButtonItem?.customView as? UIButton)
        XCTAssertEqual(closeItem.image(for: .normal), R.image.iconClose())
        let presentation = try XCTUnwrap(navigation.presentationController)
        XCTAssertFalse(navigation.presentationControllerShouldDismiss(presentation), "Important screens cannot be swiped away")
        navigation.presentationControllerDidAttemptToDismiss(presentation)
        XCTAssertTrue(CovEHost.spin(until: { navigation.presentedViewController != nil }), "A swipe asks before cancelling")
        navigation.presentedViewController?.dismiss(animated: false)
        XCTAssertTrue(CovEHost.spin(until: { navigation.presentedViewController == nil }))

        let pushed = CovEBarlessScreen()
        navigation.pushViewController(pushed, animated: false)
        navigation.view.layoutIfNeeded()
        XCTAssertTrue(navigation.isNavigationBarHidden, "Bar-less screens hide the bar")
        XCTAssertTrue(pushed.navigationControlling === navigation)
        XCTAssertEqual(pushed.navigationItem.backBarButtonItem?.title, " ")
        XCTAssertFalse(navigation.presentationControllerShouldDismiss(presentation))

        closeItem.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovEHost.spin(until: { host.presentedViewController == nil }), "Close dismisses the flow")

        let plain = ImportantFlowNavigationController(rootViewController: UIViewController(), localizationManager: LocalizationManager.shared)
        let presentationPlain = UIPresentationController(presentedViewController: plain, presenting: nil)
        XCTAssertTrue(plain.presentationControllerShouldDismiss(presentationPlain), "Ordinary flows can be swiped away")
    }
}

@MainActor
final class CovESelectableListTests: XCTestCase {
    func testSelectableListShowsRowsSearchesAndSelects() throws {
        let presenter = CovESearchablePresenter(items: [
            SelectableIconDetailsListViewModel(title: "Polkadot", subtitle: "DOT", icon: nil, isSelected: true, identifier: "dot"),
            SelectableIconDetailsListViewModel(title: "Kusama", subtitle: "KSM", icon: nil, isSelected: false, identifier: "ksm")
        ])
        let controller = SelectableListViewController<SelectionIconDetailsTableViewCell>(listPresenter: presenter)
        let navigation = UINavigationController(rootViewController: UIViewController())
        let window = CovEHost.window(for: navigation)
        defer { CovEHost.close(window) }
        navigation.pushViewController(controller, animated: false)
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
        let table = controller.rootView.tableView
        XCTAssertTrue(table.dataSource === controller)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        let cell = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 1, section: 0)) as? SelectionIconDetailsTableViewCell)
        XCTAssertEqual(cell.titleLabel.text, "Kusama")
        XCTAssertTrue(cell.checkmarkImageView.isHidden)
        controller.tableView(table, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.titleLabel.text, "Polkadot")
        controller.tableView(table, willDisplay: UITableViewCell(), forRowAt: IndexPath(row: 0, section: 0))
        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.selected, [1])

        controller.rootView.searchTextField.onTextDidChanged?("kus")
        XCTAssertEqual(presenter.searches, ["kus"])
        controller.bind(viewModel: nil)
        controller.didReload()
        XCTAssertTrue(controller.rootView.emptyView.isHidden, "A list with rows hides the empty state")
        controller.reloadCell(at: IndexPath(row: 0, section: 0))
        XCTAssertNotNil(controller.target)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(20), 0)
        controller.updateWhileKeyboardFrameChanging(.zero)

        presenter.items = []
        controller.didReload()
        XCTAssertFalse(controller.rootView.emptyView.isHidden, "An empty list shows the empty state")
        controller.beginAppearanceTransition(true, animated: false)
        controller.endAppearanceTransition()
        controller.beginAppearanceTransition(false, animated: false)
        controller.endAppearanceTransition()
        XCTAssertNil(controller.keyboardHandler)
    }
}

final class CovESearchablePresenter: SelectionListPresenterProtocol {
    var items: [SelectableViewModelProtocol]
    private(set) var selected: [Int] = []
    private(set) var searches: [String?] = []

    init(items: [SelectableViewModelProtocol]) {
        self.items = items
    }

    var numberOfItems: Int {
        items.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        items[index]
    }

    func selectItem(at index: Int) {
        selected.append(index)
    }

    func searchItem(with text: String?) {
        searches.append(text)
    }
}

final class CovEImportantScreen: UIViewController, ImportantViewProtocol {}

final class CovEBarlessScreen: UIViewController, HiddableBarWhenPushed, NavigationDependable {
    weak var navigationControlling: NavigationControlling?
}
