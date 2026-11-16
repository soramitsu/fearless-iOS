import XCTest
import UIKit
import SoraFoundation
import SSFUtils
@testable import fearless

final class CovJMxRawView: UIViewController, RawDataViewInput {
    var texts: [String] = []
    func didReceive(text: String) { texts.append(text) }
}

final class CovJMxRawInteractor: RawDataInteractorInput {
    weak var output: RawDataInteractorOutput?
    func setup(with output: RawDataInteractorOutput) { self.output = output }
}

final class CovJMxRawRouter: CovJSheetSpy, RawDataRouterInput {
    var dismissals = 0
    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }
}

final class CovJMxRawViewOutput: RawDataViewOutput {
    var loads = 0
    var closes = 0
    func didLoad(view _: RawDataViewInput) { loads += 1 }
    func close() { closes += 1 }
}

final class CovJMxRawDataTests: XCTestCase {
    func testPlainStringsAreShownVerbatim() throws {
        let (presenter, view, interactor, router) = try makeModule(json: .stringValue("0xdeadbeef"))

        presenter.didLoad(view: view)

        XCTAssertTrue(interactor.output === presenter)
        XCTAssertEqual(view.texts, ["0xdeadbeef"])
        XCTAssertTrue(router.errors.isEmpty)
    }

    func testStructuredPayloadIsPrettyPrinted() throws {
        let json = JSON.dictionaryValue([
            "amount": .unsignedIntValue(5),
            "flags": .arrayValue([.boolValue(true), .null])
        ])
        let (presenter, view, _, _) = try makeModule(json: json)

        presenter.didLoad(view: view)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let expected = try XCTUnwrap(String(data: encoder.encode(json), encoding: .utf8))
        XCTAssertEqual(view.texts, [expected])
        let text = try XCTUnwrap(view.texts.first)
        XCTAssertTrue(text.contains("\"amount\" : 5"))
        XCTAssertTrue(text.contains("\n"))
    }

    func testUnencodableValueIsReportedAndCloseDismisses() throws {
        let (presenter, view, _, router) = try makeModule(json: .doubleValue(.nan))

        presenter.didLoad(view: view)
        presenter.close()
        presenter.applyLocalization()

        XCTAssertTrue(view.texts.isEmpty)
        XCTAssertEqual(router.errors.count, 1)
        XCTAssertTrue(router.errors.first is EncodingError)
        XCTAssertEqual(router.dismissals, 1)
    }

    func testControllerShowsTextAndBothCloseControlsClose() throws {
        let output = CovJMxRawViewOutput()
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))
        let controller = RawDataViewController(output: output, localizationManager: manager)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let layout = try XCTUnwrap(controller.view as? RawDataViewLayout)

        controller.didReceive(text: "payload")
        layout.closeButton.sendActions(for: .touchUpInside)
        layout.navigationBar.backButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(output.loads, 1)
        XCTAssertEqual(output.closes, 2)
        XCTAssertEqual(layout.label.text, "payload")
        XCTAssertEqual(
            layout.closeButton.imageWithTitleView?.title,
            R.string.localizable.commonClose(preferredLanguages: manager.selectedLocale.rLanguages)
        )
    }

    func testAssembledModuleShowsPayloadAndClosesWhenPresented() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer {
            root.presentedViewController?.dismiss(animated: false)
            window.isHidden = true
        }
        let module = try XCTUnwrap(RawDataAssembly.configureModule(json: .stringValue("assembled")))
        XCTAssertTrue(module.input is RawDataPresenter)
        let controller = try XCTUnwrap(module.view.controller as? RawDataViewController)

        root.present(controller, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === controller && !controller.isBeingPresented })
        let layout = try XCTUnwrap(controller.view as? RawDataViewLayout)
        XCTAssertEqual(layout.label.text, "assembled")

        layout.closeButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(CovJWait.until(timeout: 3) { root.presentedViewController == nil })
    }

    private func makeModule(json: JSON) throws -> (RawDataPresenter, CovJMxRawView, CovJMxRawInteractor, CovJMxRawRouter) {
        let view = CovJMxRawView()
        let interactor = CovJMxRawInteractor()
        let router = CovJMxRawRouter()
        let presenter = RawDataPresenter(
            json: json,
            interactor: interactor,
            router: router,
            localizationManager: try XCTUnwrap(LocalizationManager(localization: "en"))
        )
        return (presenter, view, interactor, router)
    }
}
