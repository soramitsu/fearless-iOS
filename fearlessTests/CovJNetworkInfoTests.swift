import XCTest
import UIKit
import SoraFoundation
import SoraUI
import SSFModels
@testable import fearless

final class CovJNetworkInfoOutput: NetworkInfoPresenterProtocol {
    var setups = 0
    var copies = 0
    var closes = 0
    var updates = 0
    func setup() { setups += 1 }
    func activateCopy() { copies += 1 }
    func activateClose() { closes += 1 }
    func activateUpdate() { updates += 1 }
}

final class CovJNetworkInfoView: UIViewController, NetworkInfoViewProtocol {
    var name: InputViewModelProtocol?
    var node: InputViewModelProtocol?
    var chain: ChainModel?
    var starts = 0
    var stops = 0
    func set(nameViewModel: InputViewModelProtocol) { name = nameViewModel }
    func set(nodeViewModel: InputViewModelProtocol) { node = nodeViewModel }
    func set(chain: ChainModel) { self.chain = chain }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJNetworkInfoInteractor: NetworkInfoInteractorInputProtocol {
    var updates: [(ChainNodeModel, URL, String)] = []
    func updateNode(_ node: ChainNodeModel, newURL: URL, newName: String) { updates.append((node, newURL, newName)) }
}

final class CovJNetworkInfoRouter: NetworkInfoWireframeProtocol {
    var closes = 0
    var errors: [Error] = []
    var handlesError = true
    func close(view: NetworkInfoViewProtocol?) { closes += 1 }
    func present(error: Error, from view: ControllerBackedProtocol?, locale: Locale?) -> Bool {
        errors.append(error)
        return handlesError
    }
}

final class CovJNetworkInfoTests: XCTestCase {
    func testEditableNodeRequiresChangeAndCompleteInputs() throws {
        let output = CovJNetworkInfoOutput()
        let controller = NetworkInfoViewController(nib: R.nib.networkInfoViewController)
        controller.presenter = output
        controller.localizationManager = LocalizationManager.shared
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        controller.applyLocalization()
        XCTAssertEqual(output.setups, 1)
        let name = InputHandler(value: "Original", predicate: NSPredicate.notEmpty)
        let node = InputHandler(value: "wss://original.invalid", predicate: NSPredicate.websocket)
        controller.set(nameViewModel: InputViewModel(inputHandler: name))
        controller.set(nodeViewModel: InputViewModel(inputHandler: node))
        controller.set(chain: CovJWalletConnectFixture.chain())
        let fields = CovJViewFixture.descendants(AnimatedTextField.self, in: controller.view)
        let nameField = try XCTUnwrap(fields.first { $0.text == "Original" })
        let nodeField = try XCTUnwrap(fields.first { $0.text == "wss://original.invalid" })
        XCTAssertEqual(nameField.textField.returnKeyType, .done)
        XCTAssertEqual(nodeField.textField.keyboardType, .URL)
        XCTAssertEqual(nodeField.textField.autocapitalizationType, .none)
        let button = try XCTUnwrap(CovJViewFixture.descendants(TriangularedButton.self, in: controller.view).first {
            $0.imageWithTitleView?.title == R.string.localizable.commonUpdate(preferredLanguages: controller.selectedLocale.rLanguages)
        })
        XCTAssertFalse(button.isEnabled)
        name.changeValue(to: "Renamed")
        nameField.text = "stale"
        controller.perform(NSSelectorFromString("nameFieldDidChange"))
        XCTAssertEqual(nameField.text, "Renamed")
        XCTAssertTrue(button.isEnabled)
        node.changeValue(to: "invalid")
        controller.perform(NSSelectorFromString("nodeFieldDidChange"))
        XCTAssertEqual(nodeField.text, "invalid")
        XCTAssertFalse(button.isEnabled)
        node.changeValue(to: "wss://new.invalid")
        controller.perform(NSSelectorFromString("nodeFieldDidChange"))
        XCTAssertTrue(button.isEnabled)
        button.sendActions(for: .touchUpInside)
        controller.perform(NSSelectorFromString("actionNodeCopy"))
        controller.perform(NSSelectorFromString("actionClose"))
        XCTAssertEqual(output.updates, 1)
        XCTAssertEqual(output.copies, 1)
        XCTAssertEqual(output.closes, 1)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(nodeField))
        let texts = CovJViewFixture.descendants(UILabel.self, in: controller.view).compactMap(\.text)
        XCTAssertTrue(texts.contains("Ethereum"))
    }

    func testReadOnlyNodeRemovesUpdateAndRejectsEdits() throws {
        let output = CovJNetworkInfoOutput()
        let controller = NetworkInfoViewController(nib: R.nib.networkInfoViewController)
        controller.presenter = output
        controller.localizationManager = LocalizationManager.shared
        controller.loadViewIfNeeded()
        let fields = CovJViewFixture.descendants(AnimatedTextField.self, in: controller.view)
        XCTAssertTrue(controller.animatedTextField(try XCTUnwrap(fields.first), shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        controller.set(nameViewModel: InputViewModel(inputHandler: InputHandler(value: "Name", enabled: true)))
        controller.set(nodeViewModel: InputViewModel(inputHandler: InputHandler(value: "wss://node.invalid", enabled: true)))
        controller.set(nameViewModel: InputViewModel(inputHandler: InputHandler(value: "Name", enabled: false)))
        controller.set(nodeViewModel: InputViewModel(inputHandler: InputHandler(value: "wss://node.invalid", enabled: false)))
        XCTAssertTrue(fields.allSatisfy { !$0.isUserInteractionEnabled })
        XCTAssertTrue(CovJViewFixture.descendants(TriangularedButton.self, in: controller.view).filter {
            $0.imageWithTitleView?.title == R.string.localizable.commonUpdate(preferredLanguages: controller.selectedLocale.rLanguages)
        }.isEmpty)
        let name = try XCTUnwrap(fields.first { $0.text == "Name" })
        name.text = "Unexpected"
        XCTAssertFalse(controller.animatedTextField(name, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        XCTAssertEqual(name.text, "Name")
        let node = try XCTUnwrap(fields.first { $0.text == "wss://node.invalid" })
        node.text = "Unexpected"
        XCTAssertFalse(controller.animatedTextField(node, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))
        XCTAssertEqual(node.text, "wss://node.invalid")
        controller.set(nodeViewModel: InputViewModel(inputHandler: InputHandler(value: "wss://node.invalid")))
        XCTAssertTrue(controller.animatedTextField(node, shouldChangeCharactersIn: NSRange(location: 6, length: 4), replacementString: "other"))
    }

    func testPresenterPropagatesModeEditsAndConnectionOutcomes() throws {
        let node = ChainNodeModel(url: try XCTUnwrap(URL(string: "wss://node.invalid")), name: "Original", apikey: nil)
        let chain = CovJWalletConnectFixture.chain()
        let view = CovJNetworkInfoView()
        let interactor = CovJNetworkInfoInteractor()
        let router = CovJNetworkInfoRouter()
        let presenter = NetworkInfoPresenter(chain: chain, node: node, mode: .all, localizationManager: LocalizationManager.shared)
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = router
        presenter.setup()
        XCTAssertTrue(view.chain === chain)
        XCTAssertEqual(view.name?.inputHandler.value, "Original")
        XCTAssertEqual(view.node?.inputHandler.value, "wss://node.invalid")
        XCTAssertEqual(view.name?.inputHandler.enabled, true)
        XCTAssertEqual(view.node?.inputHandler.enabled, true)
        view.name?.inputHandler.changeValue(to: "Updated")
        view.node?.inputHandler.changeValue(to: "wss://new.invalid")
        presenter.activateUpdate()
        XCTAssertEqual(interactor.updates.count, 1)
        XCTAssertEqual(interactor.updates[0].0, node)
        XCTAssertEqual(interactor.updates[0].1.absoluteString, "wss://new.invalid")
        XCTAssertEqual(interactor.updates[0].2, "Updated")
        presenter.didStartConnectionUpdate(with: node.url)
        XCTAssertEqual(view.starts, 1)
        presenter.didCompleteConnectionUpdate(with: node.url)
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(router.closes, 1)
        presenter.activateClose()
        XCTAssertEqual(router.closes, 2)
        let error = NSError(domain: "fixture", code: 1)
        presenter.didReceive(error: error, for: node.url)
        XCTAssertEqual(router.errors.count, 1)
        router.handlesError = false
        presenter.didReceive(error: error, for: node.url)
        XCTAssertEqual(router.errors.count, 3)
        XCTAssertEqual(view.stops, 3)
        let readOnly = NetworkInfoPresenter(chain: chain, node: node, mode: .none, localizationManager: LocalizationManager.shared)
        readOnly.view = view
        readOnly.setup()
        XCTAssertEqual(view.name?.inputHandler.enabled, false)
        XCTAssertEqual(view.node?.inputHandler.enabled, false)
    }
}
