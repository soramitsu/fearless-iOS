import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SSFModels
@testable import fearless

final class CovJNetAddNodeView: UIViewController, AddCustomNodeViewProtocol {
    var names: [InputViewModelProtocol] = []
    var nodes: [InputViewModelProtocol] = []
    var starts = 0
    var stops = 0

    func didReceive(nameViewModel: InputViewModelProtocol) { names.append(nameViewModel) }
    func didReceive(nodeViewModel: InputViewModelProtocol) { nodes.append(nodeViewModel) }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
}

final class CovJNetAddNodeInteractor: AddCustomNodeInteractorInputProtocol {
    var additions: [(URL, String)] = []
    func addConnection(url: URL, name: String) { additions.append((url, name)) }
}

final class CovJNetAddNodeWireframe: CovJSheetSpy, AddCustomNodeWireframeProtocol {
    var dismissals = 0
    var handlesErrors = true

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    override func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return handlesErrors
    }
}

final class CovJNetAddNodeModuleOutput: AddCustomNodeModuleOutput {
    var changes = 0
    func didChangedNodesList() { changes += 1 }
}

final class CovJNetAddNodeOutput: AddCustomNodeInteractorOutputProtocol {
    var started: [URL] = []
    var completed: [URL] = []
    var errors: [Error] = []

    func didStartAdding(url: URL) { started.append(url) }
    func didCompleteAdding(url: URL) { completed.append(url) }
    func didReceiveError(error: Error, for _: URL) { errors.append(error) }
}

final class CovJNetAddNodePresenterSpy: AddCustomNodePresenterProtocol {
    var loads: [ObjectIdentifier] = []
    var adds = 0
    var closes = 0

    func didLoad(view: AddCustomNodeViewProtocol) { loads.append(ObjectIdentifier(view)) }
    func didTapAddNodeButton() { adds += 1 }
    func didTapCloseButton() { closes += 1 }
}

final class CovJNetAddCustomNodePresenterTests: XCTestCase {
    private func makePresenter() -> (AddCustomNodePresenter, CovJNetAddNodeView, CovJNetAddNodeInteractor, CovJNetAddNodeWireframe, CovJNetAddNodeModuleOutput) {
        let interactor = CovJNetAddNodeInteractor()
        let wireframe = CovJNetAddNodeWireframe()
        let output = CovJNetAddNodeModuleOutput()
        let presenter = AddCustomNodePresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            moduleOutput: output
        )
        let view = CovJNetAddNodeView()
        presenter.view = view
        return (presenter, view, interactor, wireframe, output)
    }

    func testAddingNeedsANameAndASecureWebsocketAddress() throws {
        let (presenter, view, interactor, _, _) = makePresenter()

        presenter.didLoad(view: view)
        let name = try XCTUnwrap(view.names.first?.inputHandler)
        let node = try XCTUnwrap(view.nodes.first?.inputHandler)
        XCTAssertEqual(name.value, "")
        XCTAssertEqual(node.value, "")
        XCTAssertFalse(name.completed)
        XCTAssertFalse(node.completed)

        presenter.didTapAddNodeButton()
        name.changeValue(to: "Mine")
        presenter.didTapAddNodeButton()
        node.changeValue(to: "https://custom.invalid")
        XCTAssertFalse(node.completed)
        presenter.didTapAddNodeButton()
        XCTAssertTrue(interactor.additions.isEmpty)

        node.changeValue(to: "wss://custom.invalid")
        presenter.didTapAddNodeButton()
        XCTAssertEqual(interactor.additions.map(\.0.absoluteString), ["wss://custom.invalid"])
        XCTAssertEqual(interactor.additions.map(\.1), ["Mine"])
    }

    func testCloseAndAddingOutcomesDriveViewWireframeAndOutput() {
        let (presenter, view, _, wireframe, output) = makePresenter()
        let url = CovJNetFixture.url("custom")

        presenter.didTapCloseButton()
        XCTAssertEqual(wireframe.dismissals, 1)

        presenter.didStartAdding(url: url)
        XCTAssertEqual(view.starts, 1)

        presenter.didCompleteAdding(url: url)
        XCTAssertEqual(view.stops, 1)
        XCTAssertEqual(output.changes, 1)
        XCTAssertEqual(wireframe.dismissals, 2)

        presenter.didReceiveError(error: AddConnectionError.alreadyExists, for: url)
        XCTAssertEqual(view.stops, 2)
        XCTAssertEqual(wireframe.errors.count, 1)
        XCTAssertEqual(wireframe.errors.first as? AddConnectionError, .alreadyExists)

        wireframe.handlesErrors = false
        presenter.didReceiveError(error: AddConnectionError.invalidConnection, for: url)
        XCTAssertEqual(view.stops, 3)
        XCTAssertEqual(wireframe.errors.count, 3)
        XCTAssertEqual(wireframe.errors[1] as? AddConnectionError, .invalidConnection)
        XCTAssertEqual(wireframe.errors.last as? CommonError, .undefined)
        XCTAssertEqual(output.changes, 1)
    }
}

final class CovJNetAddCustomNodeInteractorTests: XCTestCase {
    private struct Fixture {
        let interactor: AddCustomNodeInteractor
        let output: CovJNetAddNodeOutput
        let chains: CovJMemoryRepository<ChainModel>
        let nodes: CovJMemoryRepository<ChainNodeModel>
        let events: CovJNetEventCenterSpy
        let probe: CovJNetSubstrateFactoryStub
    }

    private func makeFixture(chain: ChainModel, knownNodes: [ChainNodeModel] = []) -> Fixture {
        let chains = CovJMemoryRepository<ChainModel>()
        let nodes = CovJMemoryRepository<ChainNodeModel>(knownNodes)
        let events = CovJNetEventCenterSpy()
        let probe = CovJNetSubstrateFactoryStub()
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        let interactor = AddCustomNodeInteractor(
            chain: chain,
            repository: AnyDataProviderRepository(chains),
            nodeRepository: AnyDataProviderRepository(nodes),
            operationManager: OperationManager(operationQueue: queue),
            eventCenter: events,
            substrateOperationFactory: probe
        )
        let output = CovJNetAddNodeOutput()
        interactor.presenter = output
        return Fixture(interactor: interactor, output: output, chains: chains, nodes: nodes, events: events, probe: probe)
    }

    func testReachableNodesAreAppendedToTheChainAndAnnounced() throws {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Add", nodes: [CovJNetFixture.node("alpha")]))
        let first = CovJNetFixture.node("mine")
        let second = CovJNetFixture.node("second")

        fixture.interactor.addConnection(url: first.url, name: "mine")
        XCTAssertEqual(fixture.output.started, [first.url])
        XCTAssertTrue(CovJWait.until { fixture.output.completed.count == 1 })
        XCTAssertEqual(fixture.probe.urls, [first.url])
        XCTAssertEqual(fixture.chains.items.first?.customNodes, [first])
        XCTAssertEqual(fixture.interactor.chain.customNodes, [first])
        XCTAssertEqual(fixture.events.chainUpdates.first?.updatedChains.first?.customNodes, [first])

        fixture.interactor.addConnection(url: second.url, name: "second")
        XCTAssertTrue(CovJWait.until { fixture.output.completed.count == 2 })
        XCTAssertEqual(fixture.output.completed, [first.url, second.url])
        XCTAssertEqual(fixture.interactor.chain.customNodes, [first, second])
        XCTAssertEqual(fixture.chains.items.first?.customNodes, [first, second])
        XCTAssertEqual(fixture.events.chainUpdates.count, 2)
        XCTAssertTrue(fixture.output.errors.isEmpty)
    }

    func testKnownNodeIsRejectedAsDuplicate() {
        let existing = CovJNetFixture.node("existing")
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Dup", custom: [existing]), knownNodes: [existing])

        fixture.interactor.addConnection(url: existing.url, name: "again")
        XCTAssertTrue(CovJWait.until { fixture.output.errors.count == 1 })

        XCTAssertEqual(fixture.output.errors.first as? AddConnectionError, .alreadyExists)
        XCTAssertTrue(fixture.output.completed.isEmpty)
        XCTAssertTrue(fixture.chains.items.isEmpty)
        XCTAssertTrue(fixture.events.events.isEmpty)
        XCTAssertEqual(fixture.interactor.chain.customNodes, [existing])
    }

    func testUnreachableNodeIsRejectedAsInvalidConnection() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Probe"))
        fixture.probe.result = .failure(CovJError("socket closed"))

        fixture.interactor.addConnection(url: CovJNetFixture.url("down"), name: "down")
        XCTAssertTrue(CovJWait.until { fixture.output.errors.count == 1 })

        XCTAssertEqual(fixture.output.errors.first as? AddConnectionError, .invalidConnection)
        XCTAssertTrue(fixture.chains.items.isEmpty)
        XCTAssertNil(fixture.interactor.chain.customNodes)
    }

    func testStorageFailureIsReported() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Disk"))
        fixture.chains.failure = CovJError("disk full")

        fixture.interactor.addConnection(url: CovJNetFixture.url("mine"), name: "mine")
        XCTAssertTrue(CovJWait.until { fixture.output.errors.count == 1 })

        XCTAssertEqual(fixture.output.errors.first as? CovJError, CovJError("disk full"))
        XCTAssertTrue(fixture.events.events.isEmpty)
    }
}

final class CovJNetAddCustomNodeControllerTests: XCTestCase {
    func testInputsEnableAddAndButtonsReachPresenter() throws {
        let presenter = CovJNetAddNodePresenterSpy()
        let controller = AddCustomNodeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        let nameField = root.nodeNameInputView.animatedInputField
        let nodeField = root.nodeAddressInputView.animatedInputField

        XCTAssertEqual(presenter.loads, [ObjectIdentifier(controller)])
        XCTAssertTrue(controller.animatedTextField(nameField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "x"))

        let name = InputHandler(predicate: NSPredicate.notEmpty)
        let node = InputHandler(predicate: NSPredicate.websocket, processor: TrimmingCharacterProcessor(charset: .whitespacesAndNewlines))
        controller.didReceive(nameViewModel: InputViewModel(inputHandler: name))
        controller.didReceive(nodeViewModel: InputViewModel(inputHandler: node))
        XCTAssertFalse(root.addNodeButton.isEnabled)

        XCTAssertTrue(controller.animatedTextField(nameField, shouldChangeCharactersIn: NSRange(location: 0, length: 0), replacementString: "Mine"))
        XCTAssertEqual(name.value, "Mine")
        XCTAssertFalse(root.addNodeButton.isEnabled)

        nodeField.text = "stale"
        let applied = controller.animatedTextField(
            nodeField,
            shouldChangeCharactersIn: NSRange(location: 0, length: 0),
            replacementString: " wss://custom.invalid "
        )
        XCTAssertFalse(applied)
        XCTAssertEqual(node.value, "wss://custom.invalid")
        XCTAssertEqual(nodeField.text, "wss://custom.invalid")
        XCTAssertTrue(root.addNodeButton.isEnabled)

        root.addNodeButton.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.adds, 1)
        XCTAssertEqual(presenter.closes, 1)
        XCTAssertFalse(controller.animatedTextFieldShouldReturn(nodeField))

        controller.didReceive(nameViewModel: InputViewModel(inputHandler: InputHandler(value: "Preset")))
        XCTAssertEqual(nameField.text, "Preset")
    }

    func testKeyboardMovesAddButtonAndLocalizationKeepsTitles() throws {
        let controller = AddCustomNodeViewController(presenter: CovJNetAddNodePresenterSpy(), localizationManager: LocalizationManager.shared)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView

        controller.viewWillAppear(false)
        XCTAssertNotNil(controller.keyboardHandler)
        XCTAssertNil(controller.target)
        XCTAssertTrue(controller.shouldApplyKeyboardFrame)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(0), UIConstants.bigOffset)
        XCTAssertEqual(controller.offsetFromKeyboardWithInset(300), UIConstants.bigOffset - controller.view.safeAreaInsets.bottom)

        root.layoutIfNeeded()
        let restingY = root.addNodeButton.frame.minY
        controller.updateWhileKeyboardFrameChanging(CGRect(x: 0, y: 544, width: 390, height: 300))
        root.layoutIfNeeded()
        XCTAssertEqual(root.addNodeButton.frame.minY, restingY - 300, accuracy: 0.5)
        controller.updateWhileKeyboardFrameChanging(.zero)
        root.layoutIfNeeded()
        XCTAssertEqual(root.addNodeButton.frame.minY, restingY, accuracy: 0.5)

        controller.viewDidDisappear(false)
        XCTAssertNil(controller.keyboardHandler)

        controller.applyLocalization()
        let title = R.string.localizable.addNodeButtonTitle(preferredLanguages: controller.selectedLocale.rLanguages)
        XCTAssertEqual(root.addNodeButton.imageWithTitleView?.title, title)
        XCTAssertEqual(
            root.nodeAddressInputView.animatedInputField.title,
            R.string.localizable.networkInfoAddress(preferredLanguages: controller.selectedLocale.rLanguages)
        )
    }

    func testFactoryWiresModuleAndCloseDismissesPresentedForm() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let output = CovJNetAddNodeModuleOutput()
        let view = try XCTUnwrap(AddCustomNodeViewFactory.createView(chain: CovJNetFixture.chain(name: "Factory"), moduleOutput: output))
        let controller = try XCTUnwrap(view.controller as? AddCustomNodeViewController)
        let presenter = try XCTUnwrap(controller.presenter as? AddCustomNodePresenter)
        XCTAssertTrue(presenter.view === controller)
        XCTAssertTrue(presenter.moduleOutput === output)
        XCTAssertTrue(presenter.wireframe is AddCustomNodeWireframe)

        host.controller.present(controller, animated: false)
        XCTAssertTrue(CovJWait.until { host.presented === controller })
        XCTAssertEqual(controller.rootView.nodeNameInputView.animatedInputField.text, "")
        XCTAssertFalse(controller.rootView.addNodeButton.isEnabled)

        controller.rootView.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovJWait.until { host.presented == nil })
        XCTAssertEqual(output.changes, 0)
    }
}
