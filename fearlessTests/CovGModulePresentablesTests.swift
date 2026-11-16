import Foundation
import SoraFoundation
import SSFModels
import UIKit
import XCTest
@testable import fearless

final class CovGModulePresentablesTests: XCTestCase {
    func testDismissStrategiesPopOrDismissDependingOnNavigationState() throws {
        let root = CovGRecordingController()
        let pushed = CovGRecordingController()
        let navigation = UINavigationController(rootViewController: root)
        navigation.setViewControllers([root, pushed], animated: false)
        CovGPushDismisser().dismiss(view: pushed)
        XCTAssertEqual(navigation.viewControllers.count, 1)

        let presented = CovGRecordingController()
        CovGPresentDismisser().dismiss(view: presented)
        XCTAssertEqual(presented.dismissCount, 1)

        let first = CovGRecordingController()
        let second = CovGRecordingController()
        let stack = UINavigationController(rootViewController: first)
        stack.setViewControllers([first, second], animated: false)
        CovGAnyDismisser().dismiss(view: second)
        XCTAssertEqual(stack.viewControllers.count, 1)
        XCTAssertEqual(second.dismissCount, 0)
        let lone = CovGRecordingController()
        _ = UINavigationController(rootViewController: lone)
        CovGAnyDismisser().dismiss(view: lone)
        XCTAssertEqual(lone.dismissCount, 1)
        CovGAnyDismisser().dismiss(view: nil)
    }

    func testDocumentPickerIsPresentedFromNavigationWithSingleSelectionFormSheet() throws {
        let content = CovGRecordingController()
        let navigation = CovGRecordingNavigation(rootViewController: content)
        let delegate = CovGPickerDelegate()
        CovGModulePresenter().presentSelectFilePicker(from: content, documentTypes: [.json], delegate: delegate)
        let picker = try XCTUnwrap(navigation.captured as? UIDocumentPickerViewController)
        XCTAssertTrue(picker.delegate === delegate)
        XCTAssertFalse(picker.allowsMultipleSelection)
        XCTAssertEqual(picker.modalPresentationStyle, .formSheet)
    }

    func testWarningFiltersAllDoneAndAccountPickerModulesArePresented() throws {
        let presenter = CovGModulePresenter()
        let view = CovGRecordingController()
        var tapped = 0
        let config = WarningAlertConfig(title: "Warning", iconImage: nil, text: "Text", buttonTitle: "OK", blocksUi: false)
        presenter.presentWarningAlert(from: view, config: config) { tapped += 1 }
        XCTAssertNotNil(view.captured)
        XCTAssertEqual(tapped, 0)

        view.captured = nil
        presenter.presentFilters(with: [FilterSet(title: "Filters", items: [])], from: view, mode: .singleSelection, moduleOutput: nil)
        XCTAssertNotNil(view.captured)
        view.captured = nil
        presenter.presentFilters(with: [], from: nil, mode: .multiSelection, moduleOutput: nil)
        XCTAssertNil(view.captured)

        let chainAsset = try ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset)
        presenter.presentDone(chainAsset: chainAsset, extrinsicHash: "0x01", from: view)
        let done = try XCTUnwrap(view.captured)
        XCTAssertEqual(done.modalPresentationStyle, .custom)
        XCTAssertNotNil(done.modalTransitioningFactory)

        view.captured = nil
        let account = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: CovGOperationFixtures.chain().accountRequest()))
        let delegate = CovGModalPickerDelegate()
        presenter.presentAccountSelection(
            [account], selectedAccountItem: account, title: LocalizableResource { _ in "Accounts" },
            delegate: delegate, from: view, context: nil
        )
        XCTAssertEqual(view.captured?.modalPresentationStyle, .custom)
    }
}

private final class CovGModulePresenter: DocumentPickerPresentable, WarningPresentable, FiltersPresentable, AllDonePresentable,
    AccountSelectionPresentable {}

private final class CovGPushDismisser: PushDismissable {}
private final class CovGPresentDismisser: PresentDismissable {}
private final class CovGAnyDismisser: AnyDismissable {}

private final class CovGRecordingController: UIViewController, ControllerBackedProtocol {
    var controller: UIViewController {
        self
    }

    var captured: UIViewController?
    private(set) var dismissCount = 0

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        captured = viewControllerToPresent
        completion?()
    }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
        completion?()
    }
}

private final class CovGRecordingNavigation: UINavigationController {
    var captured: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        captured = viewControllerToPresent
        completion?()
    }
}

private final class CovGPickerDelegate: NSObject, UIDocumentPickerDelegate {}

private final class CovGModalPickerDelegate: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_: Int, context _: AnyObject?) {}
    func modalPickerDidCancel(context _: AnyObject?) {}
    func modalPickerDidSelectAction(context _: AnyObject?) {}
}
