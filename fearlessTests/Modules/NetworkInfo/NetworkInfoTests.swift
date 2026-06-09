import XCTest
import UIKit
import FearlessFoundation
import RobinHood
import SSFModels
@testable import fearless

final class NetworkInfoTests: XCTestCase {
    func testSetup_whenModeAllowsEditing_thenProvidesEditableInputsAndChain() {
        let node = makeNode(name: "Primary", url: "wss://node.example")
        let chain = makeChain(node: node)
        let presenter = createPresenter(chain: chain, node: node, mode: .all)
        let view = NetworkInfoViewSpy()

        presenter.view = view
        presenter.setup()

        XCTAssertEqual(view.nameViewModel?.inputHandler.value, "Primary")
        XCTAssertEqual(view.nodeViewModel?.inputHandler.value, "wss://node.example")
        XCTAssertEqual(view.chain?.chainId, chain.chainId)
        XCTAssertEqual(view.nameViewModel?.inputHandler.enabled, true)
        XCTAssertEqual(view.nodeViewModel?.inputHandler.enabled, true)
    }

    func testSetup_whenReadOnlyMode_thenProvidesDisabledInputs() {
        let node = makeNode(name: "Default", url: "wss://default.example")
        let presenter = createPresenter(chain: makeChain(node: node), node: node, mode: .none)
        let view = NetworkInfoViewSpy()

        presenter.view = view
        presenter.setup()

        XCTAssertEqual(view.nameViewModel?.inputHandler.enabled, false)
        XCTAssertEqual(view.nodeViewModel?.inputHandler.enabled, false)
    }

    func testActivateCopy_whenTriggered_thenCopiesNodeUrlAndShowsSuccess() {
        let node = makeNode(name: "Sora", url: "wss://sora.example")
        let wireframe = NetworkInfoWireframeSpy()
        let presenter = createPresenter(
            chain: makeChain(node: node),
            node: node,
            mode: .none,
            wireframe: wireframe
        )
        let view = NetworkInfoViewSpy()

        presenter.view = view
        presenter.activateCopy()

        XCTAssertEqual(UIPasteboard.general.string, "wss://sora.example")
        XCTAssertNotNil(wireframe.successTitle)
        XCTAssertTrue(wireframe.successView === view)
    }

    func testActivateUpdate_whenInputsChanged_thenPassesUpdatedNodeToInteractor() {
        let node = makeNode(name: "Old", url: "wss://old.example")
        let interactor = NetworkInfoInteractorInputSpy()
        let presenter = createPresenter(
            chain: makeChain(node: node),
            node: node,
            mode: .all,
            interactor: interactor
        )
        let view = NetworkInfoViewSpy()

        presenter.view = view
        presenter.setup()
        view.nameViewModel?.inputHandler.changeValue(to: "New")
        view.nodeViewModel?.inputHandler.changeValue(to: "wss://new.example")
        presenter.activateUpdate()

        XCTAssertEqual(interactor.updatedNode, node)
        XCTAssertEqual(interactor.newURL?.absoluteString, "wss://new.example")
        XCTAssertEqual(interactor.newName, "New")
    }

    func testConnectionUpdateCallbacks_whenSuccessful_thenToggleLoadingAndClose() {
        let wireframe = NetworkInfoWireframeSpy()
        let presenter = createPresenter(wireframe: wireframe)
        let view = NetworkInfoViewSpy()
        let url = URL(string: "wss://node.example")!

        presenter.view = view
        presenter.didStartConnectionUpdate(with: url)
        presenter.didCompleteConnectionUpdate(with: url)

        XCTAssertEqual(view.didStartLoadingCallCount, 1)
        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertTrue(wireframe.closedView === view)
    }

    func testDidReceiveError_whenSpecificErrorNotPresented_thenShowsFallbackError() {
        let wireframe = NetworkInfoWireframeSpy(shouldPresentError: false)
        let presenter = createPresenter(wireframe: wireframe)
        let view = NetworkInfoViewSpy()

        presenter.view = view
        presenter.didReceive(error: NetworkInfoTestError.failure, for: URL(string: "wss://node.example")!)

        XCTAssertEqual(view.didStopLoadingCallCount, 1)
        XCTAssertEqual(wireframe.presentedErrors.count, 2)
        XCTAssertTrue(wireframe.presentedErrors.first is NetworkInfoTestError)
        XCTAssertTrue(wireframe.presentedErrors.last is CommonError)
    }

    func testInteractorUpdateNode_whenConnectionValid_thenSavesNodeAndPublishesUpdatedChain() throws {
        let oldNode = makeNode(name: "Old", url: "wss://old.example")
        let chain = makeChain(
            node: oldNode,
            selectedNode: oldNode,
            customNodes: [oldNode]
        )
        let newURL = URL(string: "wss://new.example")!
        let operationQueue = OperationQueue()
        let storageFacade = SubstrateStorageTestFacade()
        let repository: CoreDataRepository<ChainNodeModel, CDChainNode> = storageFacade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(ChainNodeModelMapper())
        )
        let eventCenter = NetworkInfoEventCenterSpy()
        let presenter = NetworkInfoInteractorOutputSpy()
        let interactor = NetworkInfoInteractor(
            chain: chain,
            nodeRepository: AnyDataProviderRepository(repository),
            substrateOperationFactory: SubstrateOperationFactoryStub(result: .success("SORA")),
            operationManager: OperationManager(operationQueue: operationQueue),
            eventCenter: eventCenter
        )
        interactor.presenter = presenter

        let completionExpectation = expectation(description: "Node update completes")
        presenter.onComplete = {
            completionExpectation.fulfill()
        }

        interactor.updateNode(oldNode, newURL: newURL, newName: "New")

        wait(for: [completionExpectation], timeout: Constants.defaultExpectationDuration)

        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperations([fetchOperation], waitUntilFinished: true)
        let savedNodes = try fetchOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
        let event = try XCTUnwrap(eventCenter.notifiedEvents.compactMap { $0 as? ChainsUpdatedEvent }.first)
        let updatedChain = try XCTUnwrap(event.updatedChains.first)

        XCTAssertEqual(savedNodes.map(\.url), [newURL])
        XCTAssertEqual(savedNodes.map(\.name), ["New"])
        XCTAssertEqual(updatedChain.customNodes?.map(\.url), [newURL])
        XCTAssertEqual(updatedChain.selectedNode?.url, newURL)
        XCTAssertEqual(presenter.startedURLs, [newURL])
        XCTAssertEqual(presenter.completedURLs, [newURL])
    }

    private func createPresenter(
        chain: ChainModel? = nil,
        node: ChainNodeModel? = nil,
        mode: NetworkInfoMode = .all,
        interactor: NetworkInfoInteractorInputProtocol = NetworkInfoInteractorInputSpy(),
        wireframe: NetworkInfoWireframeProtocol = NetworkInfoWireframeSpy()
    ) -> NetworkInfoPresenter {
        let selectedNode = node ?? makeNode(name: "Node", url: "wss://node.example")

        let presenter = NetworkInfoPresenter(
            chain: chain ?? makeChain(node: selectedNode),
            node: selectedNode,
            mode: mode,
            localizationManager: LocalizationManager.shared
        )
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        return presenter
    }

    private func makeNode(name: String, url: String) -> ChainNodeModel {
        ChainNodeModel(url: URL(string: url)!, name: name, apikey: nil)
    }

    private func makeChain(
        node: ChainNodeModel,
        selectedNode: ChainNodeModel? = nil,
        customNodes: Set<ChainNodeModel>? = nil
    ) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: UUID().uuidString,
            parentId: nil,
            paraId: nil,
            name: "SORA Mainnet",
            xcm: nil,
            nodes: [node],
            addressPrefix: 69,
            types: nil,
            icon: URL(string: "https://example.com/icon.png"),
            options: nil,
            externalApi: nil,
            selectedNode: selectedNode,
            customNodes: customNodes,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private final class NetworkInfoViewSpy: NetworkInfoViewProtocol {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var nameViewModel: InputViewModelProtocol?
    private(set) var nodeViewModel: InputViewModelProtocol?
    private(set) var chain: ChainModel?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func set(nameViewModel: InputViewModelProtocol) {
        self.nameViewModel = nameViewModel
    }

    func set(nodeViewModel: InputViewModelProtocol) {
        self.nodeViewModel = nodeViewModel
    }

    func set(chain: ChainModel) {
        self.chain = chain
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class NetworkInfoInteractorInputSpy: NetworkInfoInteractorInputProtocol {
    private(set) var updatedNode: ChainNodeModel?
    private(set) var newURL: URL?
    private(set) var newName: String?

    func updateNode(_ node: ChainNodeModel, newURL: URL, newName: String) {
        updatedNode = node
        self.newURL = newURL
        self.newName = newName
    }
}

private final class NetworkInfoInteractorOutputSpy: NetworkInfoInteractorOutputProtocol {
    private(set) var startedURLs: [URL] = []
    private(set) var completedURLs: [URL] = []
    private(set) var receivedErrors: [(Error, URL)] = []
    var onComplete: (() -> Void)?

    func didStartConnectionUpdate(with url: URL) {
        startedURLs.append(url)
    }

    func didCompleteConnectionUpdate(with url: URL) {
        completedURLs.append(url)
        onComplete?()
    }

    func didReceive(error: Error, for url: URL) {
        receivedErrors.append((error, url))
    }
}

private final class NetworkInfoWireframeSpy: NetworkInfoWireframeProtocol {
    private(set) weak var closedView: NetworkInfoViewProtocol?
    private(set) weak var successView: ControllerBackedProtocol?
    private(set) var successTitle: String?
    private(set) var presentedErrors: [Error] = []
    private(set) var presentedViewModel: SheetAlertPresentableViewModel?
    private let shouldPresentError: Bool

    init(shouldPresentError: Bool = true) {
        self.shouldPresentError = shouldPresentError
    }

    func close(view: NetworkInfoViewProtocol?) {
        closedView = view
    }

    func presentSuccessNotification(
        _ title: String,
        from view: ControllerBackedProtocol?,
        completion closure: (() -> Void)?
    ) {
        successTitle = title
        successView = view
        closure?()
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedErrors.append(error)
        return shouldPresentError
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from _: ControllerBackedProtocol?
    ) {
        presentedViewModel = viewModel
    }

    func present(
        message _: String?,
        title _: String,
        closeAction _: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {}

    func presentInfo(
        message _: String?,
        title _: String,
        from _: ControllerBackedProtocol?
    ) {}
}

private final class SubstrateOperationFactoryStub: SubstrateOperationFactoryProtocol {
    private let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func fetchChainOperation(_ url: URL) -> BaseOperation<String> {
        ClosureOperation {
            switch self.result {
            case let .success(value):
                return value
            case let .failure(error):
                throw error
            }
        }
    }
}

private final class NetworkInfoEventCenterSpy: EventCenterProtocol {
    private(set) var notifiedEvents: [EventProtocol] = []

    func notify(with event: EventProtocol) {
        notifiedEvents.append(event)
    }

    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}

    func remove(observer _: EventVisitorProtocol) {}
}

private enum NetworkInfoTestError: Error {
    case failure
}
