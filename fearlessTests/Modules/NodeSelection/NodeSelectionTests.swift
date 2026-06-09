import XCTest
import UIKit
import FearlessFoundation
import SSFModels
@testable import fearless

final class NodeSelectionTests: XCTestCase {
    func testSetup_whenViewAssigned_thenSetsUpInteractorAndProvidesLocale() {
        let interactor = NodeSelectionInteractorInputSpy()
        let presenter = createPresenter(interactor: interactor)
        let view = NodeSelectionViewSpy()

        presenter.view = view
        presenter.setup()

        XCTAssertEqual(interactor.setupCallCount, 1)
        XCTAssertEqual(view.receivedLocale, LocalizationManager.shared.selectedLocale)
    }

    func testDidReceiveChain_whenInteractorOutputsChain_thenBuildsAndProvidesViewModel() {
        let chain = ChainModelGenerator.generate(count: 1).first!
        let viewModel = NodeSelectionViewModel(title: "Network", autoSelectEnabled: true, sections: [])
        let factory = NodeSelectionViewModelFactorySpy(viewModel: viewModel)
        let presenter = createPresenter(
            interactor: NodeSelectionInteractorInputSpy(chain: chain),
            viewModelFactory: factory
        )
        let view = NodeSelectionViewSpy()

        presenter.view = view
        presenter.didReceive(chain: chain)

        XCTAssertEqual(factory.receivedChain?.chainId, chain.chainId)
        XCTAssertTrue(factory.cellsDelegate === presenter)
        guard case let .loaded(receivedViewModel)? = view.state else {
            return XCTFail("Expected loaded state")
        }
        XCTAssertEqual(receivedViewModel.title, "Network")
    }

    func testSelectionActions_whenTriggered_thenUpdateInteractorAndRoutes() {
        let chain = ChainModelGenerator.generate(count: 1).first!
        let node = chain.nodes.first!
        let interactor = NodeSelectionInteractorInputSpy(chain: chain)
        let wireframe = NodeSelectionWireframeSpy()
        let presenter = createPresenter(interactor: interactor, wireframe: wireframe)
        let view = NodeSelectionViewSpy()

        presenter.view = view
        presenter.didSelectNode(node)
        presenter.didChangeValueForAutomaticNodeSwitch(isOn: true)
        presenter.didTapAddNodeButton()
        presenter.didTapCloseButton()

        XCTAssertEqual(interactor.selectedNode, node)
        XCTAssertEqual(interactor.automaticSwitchNodes, true)
        XCTAssertEqual(wireframe.addNodeChain?.chainId, chain.chainId)
        XCTAssertTrue(wireframe.addNodeOutput === presenter)
        XCTAssertTrue(wireframe.addNodeView === view)
        XCTAssertTrue(wireframe.dismissedView === view)
    }

    func testDeleteNode_whenConfirmed_thenDeletesNode() {
        let chain = ChainModelGenerator.generate(count: 1).first!
        let node = chain.nodes.first!
        let interactor = NodeSelectionInteractorInputSpy(chain: chain)
        let wireframe = NodeSelectionWireframeSpy()
        let presenter = createPresenter(interactor: interactor, wireframe: wireframe)
        let view = NodeSelectionViewSpy()

        presenter.view = view
        presenter.deleteNode(node)
        wireframe.presentedViewModel?.actions.first?.handler?()

        XCTAssertEqual(wireframe.presentedViewModel?.message, node.name)
        XCTAssertTrue(wireframe.presentedView === view)
        XCTAssertEqual(interactor.deletedNode, node)
    }

    func testNodeInfoActions_whenTriggered_thenPresentExpectedModes() {
        let chain = ChainModelGenerator.generate(count: 1).first!
        let node = chain.nodes.first!
        let wireframe = NodeSelectionWireframeSpy()
        let presenter = createPresenter(
            interactor: NodeSelectionInteractorInputSpy(chain: chain),
            wireframe: wireframe
        )
        let view = NodeSelectionViewSpy()

        presenter.view = view
        presenter.showDefaultNodeInfo(node)
        XCTAssertEqual(wireframe.nodeInfoMode, NetworkInfoMode.none)

        presenter.showCustomNodeInfo(node)
        XCTAssertEqual(wireframe.nodeInfoMode, NetworkInfoMode.all)
        XCTAssertEqual(wireframe.nodeInfoChain?.chainId, chain.chainId)
        XCTAssertEqual(wireframe.nodeInfoNode, node)
        XCTAssertTrue(wireframe.nodeInfoView === view)
    }

    func testApplyLocalization_whenViewAssigned_thenRebuildsViewModelAndProvidesLocale() {
        let factory = NodeSelectionViewModelFactorySpy()
        let presenter = createPresenter(viewModelFactory: factory)
        let view = NodeSelectionViewSpy()

        presenter.view = view
        presenter.applyLocalization()

        XCTAssertNotNil(view.state)
        XCTAssertEqual(view.receivedLocale, LocalizationManager.shared.selectedLocale)
        XCTAssertNotNil(factory.receivedChain)
    }

    private func createPresenter(
        interactor: NodeSelectionInteractorInputProtocol = NodeSelectionInteractorInputSpy(),
        wireframe: NodeSelectionWireframeProtocol = NodeSelectionWireframeSpy(),
        viewModelFactory: NodeSelectionViewModelFactoryProtocol = NodeSelectionViewModelFactorySpy()
    ) -> NodeSelectionPresenter {
        NodeSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class NodeSelectionViewSpy: NodeSelectionViewProtocol {
    let controller = UIViewController()
    let isSetup = false
    let loadableContentView = UIView()
    let shouldDisableInteractionWhenLoading = true
    private(set) var state: NodeSelectionViewState?
    private(set) var receivedLocale: Locale?
    private(set) var didStartLoadingCallCount = 0
    private(set) var didStopLoadingCallCount = 0

    func didReceive(state: NodeSelectionViewState) {
        self.state = state
    }

    func didReceive(locale: Locale) {
        receivedLocale = locale
    }

    func didStartLoading() {
        didStartLoadingCallCount += 1
    }

    func didStopLoading() {
        didStopLoadingCallCount += 1
    }
}

private final class NodeSelectionInteractorInputSpy: NodeSelectionInteractorInputProtocol {
    private(set) var setupCallCount = 0
    private(set) var selectedNode: ChainNodeModel?
    private(set) var automaticSwitchNodes: Bool?
    private(set) var deletedNode: ChainNodeModel?
    var chain: ChainModel

    init(chain: ChainModel = ChainModelGenerator.generate(count: 1).first!) {
        self.chain = chain
    }

    func setup() {
        setupCallCount += 1
    }

    func selectNode(_ node: ChainNodeModel?) {
        selectedNode = node
    }

    func setAutomaticSwitchNodes(_ automatic: Bool) {
        automaticSwitchNodes = automatic
    }

    func deleteNode(_ node: ChainNodeModel) {
        deletedNode = node
    }
}

private final class NodeSelectionWireframeSpy: NodeSelectionWireframeProtocol {
    private(set) weak var dismissedView: ControllerBackedProtocol?
    private(set) weak var addNodeView: ControllerBackedProtocol?
    private(set) weak var presentedView: ControllerBackedProtocol?
    private(set) weak var nodeInfoView: ControllerBackedProtocol?
    private(set) weak var addNodeOutput: AddCustomNodeModuleOutput?
    private(set) var addNodeChain: ChainModel?
    private(set) var presentedViewModel: SheetAlertPresentableViewModel?
    private(set) var presentedTitle: String?
    private(set) var nodeInfoChain: ChainModel?
    private(set) var nodeInfoNode: ChainNodeModel?
    private(set) var nodeInfoMode: NetworkInfoMode?
    private(set) var presentedError: Error?

    func dismiss(view: ControllerBackedProtocol?) {
        dismissedView = view
    }

    func presentAddNodeFlow(
        with chain: ChainModel,
        moduleOutput: AddCustomNodeModuleOutput?,
        from view: ControllerBackedProtocol?
    ) {
        addNodeChain = chain
        addNodeOutput = moduleOutput
        addNodeView = view
    }

    func presentNodeInfo(
        chain: ChainModel,
        node: ChainNodeModel,
        mode: NetworkInfoMode,
        from view: ControllerBackedProtocol?
    ) {
        nodeInfoChain = chain
        nodeInfoNode = node
        nodeInfoMode = mode
        nodeInfoView = view
    }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        presentedError = error
        return true
    }

    func present(
        viewModel: SheetAlertPresentableViewModel,
        from view: ControllerBackedProtocol?
    ) {
        presentedViewModel = viewModel
        presentedView = view
    }

    func present(
        message _: String?,
        title: String,
        closeAction _: String?,
        from view: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        presentedTitle = title
        presentedView = view
    }

    func presentInfo(
        message _: String?,
        title: String,
        from view: ControllerBackedProtocol?
    ) {
        presentedTitle = title
        presentedView = view
    }
}

private final class NodeSelectionViewModelFactorySpy: NodeSelectionViewModelFactoryProtocol {
    private(set) var receivedChain: ChainModel?
    private(set) weak var cellsDelegate: NodeSelectionTableCellViewModelDelegate?
    private let viewModel: NodeSelectionViewModel

    init(
        viewModel: NodeSelectionViewModel = NodeSelectionViewModel(
            title: "Chain",
            autoSelectEnabled: false,
            sections: []
        )
    ) {
        self.viewModel = viewModel
    }

    func buildViewModel(
        from chain: ChainModel,
        locale _: Locale,
        cellsDelegate: NodeSelectionTableCellViewModelDelegate?
    ) -> NodeSelectionViewModel {
        receivedChain = chain
        self.cellsDelegate = cellsDelegate
        return viewModel
    }

    func buildDeleteNodeAlertViewModel(
        node: ChainNodeModel,
        locale _: Locale,
        deleteHandler: @escaping () -> Void
    ) -> SheetAlertPresentableViewModel {
        SheetAlertPresentableViewModel(
            title: "Delete",
            message: node.name,
            actions: [
                SheetAlertPresentableAction(title: "Confirm", handler: deleteHandler)
            ],
            closeAction: nil
        )
    }
}
