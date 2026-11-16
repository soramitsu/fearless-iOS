@testable import fearless
import SafariServices
import SSFModels
import UIKit
import XCTest

final class CovGPresentationTests: XCTestCase {
    func testBalanceAndFeeErrorsProvideLocalizedTitlesAndCloseActions() throws {
        let presenter = CovGAlertPresenter()
        let view = CovGPresentationController()
        let locale = Locale(identifier: "en_US")
        let actions: [(ControllerBackedProtocol, Locale?) -> Void] = [
            presenter.presentAmountTooHigh, presenter.presentFeeNotReceived, presenter.presentExtrinsicFailed,
            presenter.presentFeeTooHigh, presenter.presentExsitentialDepositNotReceived,
        ]
        for action in actions {
            presenter.message = nil
            action(view, locale)
            let message = try XCTUnwrap(presenter.message)
            XCTAssertFalse(message.0.isEmpty)
            XCTAssertFalse(try XCTUnwrap(message.1).isEmpty)
            XCTAssertFalse(try XCTUnwrap(message.2).isEmpty)
            XCTAssertTrue(presenter.source === view)
        }
        presenter.presentSoraBridgeLowAmountError(from: view, locale: locale, assetAmount: "53 UNIT")
        XCTAssertTrue(try XCTUnwrap(presenter.message?.1).contains("53 UNIT"))
    }

    func testExistentialWarningsPreserveAmountsAndActionCallbacks() throws {
        let presenter = CovGAlertPresenter()
        let view = CovGPresentationController()
        let locale = Locale(identifier: "en_US")
        var proceeded = 0
        presenter.presentExistentialDepositWarning(existentianDepositValue: "5 UNIT", from: view, action: { proceeded += 1 }, locale: locale)
        let single = try XCTUnwrap(presenter.model)
        XCTAssertTrue(try XCTUnwrap(single.message).contains("5 UNIT"))
        XCTAssertEqual(single.actions.count, 1)
        XCTAssertNotNil(single.closeAction)
        single.actions[0].handler?()
        XCTAssertEqual(proceeded, 1)
        var maximum = 0
        var cancelled = 0
        presenter.presentExistentialDepositWarning(
            existentianDepositValue: "6 UNIT", from: view, proceedHandler: { proceeded += 1 },
            setMaxHandler: { maximum += 1 }, cancelHandler: { cancelled += 1 }, locale: locale
        )
        let multiple = try XCTUnwrap(presenter.model)
        XCTAssertTrue(try XCTUnwrap(multiple.message).contains("6 UNIT"))
        XCTAssertEqual(multiple.actions.count, 3)
        XCTAssertNil(multiple.closeAction)
        multiple.actions.forEach { $0.handler?() }
        XCTAssertEqual(proceeded, 2)
        XCTAssertEqual(maximum, 1)
        XCTAssertEqual(cancelled, 1)
        presenter.presentExistentialDepositError(existentianDepositValue: "7 UNIT", from: view, locale: locale)
        XCTAssertTrue(try XCTUnwrap(presenter.model?.message).contains("7 UNIT"))
        XCTAssertTrue(try XCTUnwrap(presenter.model).actions.isEmpty)
        presenter.presentDestinationExistentialDepositError(from: view, locale: locale)
        XCTAssertFalse(try XCTUnwrap(presenter.model).title.isEmpty)
        XCTAssertNotNil(presenter.model?.closeAction)
    }

    func testActionSheetsContainExpectedActionsWithoutReadingPasteboard() throws {
        let presenter = CovGSystemPresenter()
        let view = CovGPresentationController()
        let locale = Locale(identifier: "en_US")
        presenter.presentCopy(with: "identifier", locale: locale, from: view)
        let copy = try XCTUnwrap(view.captured as? UIAlertController)
        XCTAssertEqual(copy.title, "identifier")
        XCTAssertEqual(copy.preferredStyle, .actionSheet)
        XCTAssertEqual(copy.actions.map(\.style), [.default, .cancel])
        XCTAssertFalse(copy.actions.compactMap(\.title).contains(""))
        try presenter.presentOptions(with: "hash", locale: locale, chain: CovGOperationFixtures.chain(), from: view)
        let hash = try XCTUnwrap(view.captured as? UIAlertController)
        XCTAssertEqual(hash.actions.map(\.style), [.default, .cancel])
        try presenter.presentAccountOptions(from: view, address: "owner", chain: CovGOperationFixtures.chain(), locale: locale, exportClosure: {})
        let address = try XCTUnwrap(view.captured as? UIAlertController)
        XCTAssertEqual(address.actions.last?.style, .cancel)
        XCTAssertGreaterThanOrEqual(address.actions.count, 3)
    }

    func testSharingForwardsCompletionForSingleAndMultipleSources() throws {
        let presenter = CovGSystemPresenter()
        let view = CovGPresentationController()
        var results: [Bool] = []
        presenter.share(sources: ["text", URL(string: "https://share.invalid") as Any], from: view) { results.append($0) }
        let multiple = try XCTUnwrap(view.captured as? UIActivityViewController)
        multiple.completionWithItemsHandler?(nil, true, nil, nil)
        XCTAssertEqual(results, [true])
        presenter.share(source: CovGActivityItem(), from: view) { results.append($0) }
        let single = try XCTUnwrap(view.captured as? UIActivityViewController)
        single.completionWithItemsHandler?(nil, false, nil, nil)
        XCTAssertEqual(results, [true, false])
        presenter.share(sources: ["text"], from: view, with: nil)
        XCTAssertNil((view.captured as? UIActivityViewController)?.completionWithItemsHandler)
    }

    func testSettingsWebAndSuccessRoutesBuildExpectedControllers() throws {
        let presenter = CovGSystemPresenter()
        let view = CovGPresentationController()
        presenter.askOpenApplicationSettings(with: "Allow access", title: "Permission", from: view)
        let settings = try XCTUnwrap(view.captured as? UIAlertController)
        XCTAssertEqual(settings.title, "Permission")
        XCTAssertEqual(settings.message, "Allow access")
        XCTAssertEqual(settings.actions.map(\.style), [.cancel, .default])
        for style in [WebPresentableStyle.automatic, .modal] {
            try presenter.showWeb(url: XCTUnwrap(URL(string: "https://web.invalid")), from: view, style: style)
            XCTAssertTrue(view.captured is SFSafariViewController)
            if case .modal = style {
                XCTAssertEqual(view.captured?.modalPresentationStyle, .overFullScreen)
            }
        }
        var completed = false
        presenter.presentSuccessNotification("Done", from: view as ControllerBackedProtocol, completion: { completed = true })
        XCTAssertTrue(completed)
        XCTAssertNotNil(view.captured)
    }

    func testSheetPresentationStylesAndInformationContent() {
        let presenter = CovGSheetPresenter()
        let view = CovGPresentationController()
        presenter.present(message: "Message", title: "Title", closeAction: "Close", from: view)
        XCTAssertTrue(view.captured is SheetAletViewController)
        XCTAssertEqual(view.captured?.modalPresentationStyle, .custom)
        presenter.presentInfo(message: "Information", title: "Info", from: view)
        XCTAssertTrue(view.captured is SheetAletViewController)
        let model = SheetAlertPresentableViewModel(title: "Custom", message: "Message", actions: [], closeAction: "Close")
        presenter.present(viewModel: model, from: view)
        XCTAssertEqual(view.captured?.modalPresentationStyle, .custom)
        XCTAssertNotNil(view.captured?.modalTransitioningFactory)
    }
}

private final class CovGAlertPresenter: SheetAlertPresentable {
    var message: (String, String?, String?)?
    var model: SheetAlertPresentableViewModel?
    weak var source: ControllerBackedProtocol?
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }

    func present(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        model = viewModel; source = view
    }

    func present(message: String?, title: String, closeAction: String?, from view: ControllerBackedProtocol?, actions _: [SheetAlertPresentableAction]) {
        self.message = (title, message, closeAction); source = view
    }
}

private final class CovGSheetPresenter: SheetAlertPresentable {
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

private final class CovGSystemPresenter: TextCopyPresentable, ExtrinsicOptionsPresentable, AddressOptionsPresentable,
    SharingPresentable, ApplicationSettingsPresentable, WebPresentable, ModalAlertPresenting {}

private final class CovGPresentationController: UIViewController, ControllerBackedProtocol {
    var controller: UIViewController {
        self
    }

    var captured: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        captured = viewControllerToPresent
        completion?()
    }
}

private final class CovGActivityItem: NSObject, UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        "text"
    }

    func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivity.ActivityType?) -> Any? {
        "text"
    }
}
