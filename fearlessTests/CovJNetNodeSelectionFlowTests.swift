import XCTest
import UIKit
import SoraFoundation
import SoraUI
import SSFModels
import RobinHood
@testable import fearless

final class CovJNetNodeView: UIViewController, NodeSelectionViewProtocol {
    var states: [NodeSelectionViewState] = []
    var locales: [Locale] = []

    var loadedModels: [NodeSelectionViewModel] {
        states.compactMap { state in
            if case let .loaded(viewModel) = state { return viewModel }
            return nil
        }
    }

    func didReceive(state: NodeSelectionViewState) { states.append(state) }
    func didReceive(locale: Locale) { locales.append(locale) }
}

final class CovJNetNodeInteractor: NodeSelectionInteractorInputProtocol {
    var chain: ChainModel
    var setups = 0
    var selected: [ChainNodeModel?] = []
    var automatic: [Bool] = []
    var deleted: [ChainNodeModel] = []

    init(chain: ChainModel) { self.chain = chain }

    func setup() { setups += 1 }
    func selectNode(_ node: ChainNodeModel?) { selected.append(node) }
    func setAutomaticSwitchNodes(_ automatic: Bool) { self.automatic.append(automatic) }
    func deleteNode(_ node: ChainNodeModel) { deleted.append(node) }
}

final class CovJNetNodeWireframe: CovJSheetSpy, NodeSelectionWireframeProtocol {
    var dismissals = 0
    var addFlows: [(String, ObjectIdentifier?)] = []
    var nodeInfos: [(ChainNodeModel, NetworkInfoMode)] = []

    func dismiss(view _: ControllerBackedProtocol?) { dismissals += 1 }

    func presentAddNodeFlow(with chain: ChainModel, moduleOutput: AddCustomNodeModuleOutput?, from _: ControllerBackedProtocol?) {
        addFlows.append((chain.chainId, moduleOutput.map { ObjectIdentifier($0) }))
    }

    func presentNodeInfo(chain _: ChainModel, node: ChainNodeModel, mode: NetworkInfoMode, from _: ControllerBackedProtocol?) {
        nodeInfos.append((node, mode))
    }
}

final class CovJNetNodeOutput: NodeSelectionInteractorOutputProtocol {
    var chains: [ChainModel] = []
    func didReceive(chain: ChainModel) { chains.append(chain) }
}

final class CovJNetNodeSelectionPresenterTests: XCTestCase {
    private let alpha = CovJNetFixture.node("alpha")
    private let beta = CovJNetFixture.node("beta")
    private let custom = CovJNetFixture.node("custom")

    private func makePresenter() -> (NodeSelectionPresenter, CovJNetNodeView, CovJNetNodeInteractor, CovJNetNodeWireframe) {
        let chain = CovJNetFixture.chain(name: "Nodes", nodes: [beta, alpha], custom: [custom], selected: alpha)
        let interactor = CovJNetNodeInteractor(chain: chain)
        let wireframe = CovJNetNodeWireframe()
        let presenter = NodeSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: NodeSelectionViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )
        let view = CovJNetNodeView()
        presenter.view = view
        return (presenter, view, interactor, wireframe)
    }

    func testSetupSendsLocaleAndChainUpdatesRebuildSections() throws {
        let (presenter, view, interactor, _) = makePresenter()

        presenter.setup()
        XCTAssertEqual(interactor.setups, 1)
        XCTAssertEqual(view.locales, [CovJNetFixture.locale])
        XCTAssertTrue(view.states.isEmpty)

        presenter.didReceive(chain: interactor.chain)
        let model = try XCTUnwrap(view.loadedModels.last)
        XCTAssertEqual(model.title, "Nodes")
        XCTAssertFalse(model.autoSelectEnabled)
        XCTAssertEqual(model.sections.map { $0.viewModels.map(\.node) }, [[custom], [alpha, beta]])
        XCTAssertTrue(model.sections.flatMap(\.viewModels).allSatisfy { $0.delegate === presenter })
        XCTAssertEqual(model.sections[1].viewModels.map(\.selected), [true, false])

        presenter.applyLocalization()
        XCTAssertEqual(view.loadedModels.count, 2)
        XCTAssertEqual(view.locales.count, 2)

        presenter.didChangedNodesList()
        XCTAssertEqual(view.states.count, 2)
    }

    func testInputsReachInteractorAndWireframe() {
        let (presenter, _, interactor, wireframe) = makePresenter()

        presenter.didSelectNode(beta)
        presenter.didChangeValueForAutomaticNodeSwitch(isOn: true)
        presenter.didChangeValueForAutomaticNodeSwitch(isOn: false)
        presenter.didTapCloseButton()
        presenter.didTapAddNodeButton()

        XCTAssertEqual(interactor.selected, [beta])
        XCTAssertEqual(interactor.automatic, [true, false])
        XCTAssertEqual(wireframe.dismissals, 1)
        XCTAssertEqual(wireframe.addFlows.map(\.0), [interactor.chain.chainId])
        XCTAssertEqual(wireframe.addFlows.first?.1, ObjectIdentifier(presenter))
    }

    func testCellActionsShowNodeInfoAndConfirmDeletion() throws {
        let (presenter, view, interactor, wireframe) = makePresenter()
        presenter.didReceive(chain: interactor.chain)
        let model = try XCTUnwrap(view.loadedModels.last)

        model.sections[0].viewModels[0].didTapInfoButton()
        model.sections[1].viewModels[1].didTapInfoButton()
        XCTAssertEqual(wireframe.nodeInfos.map(\.0), [custom, beta])
        XCTAssertEqual(wireframe.nodeInfos.map(\.1), [NetworkInfoMode.all, NetworkInfoMode.none])

        model.sections[0].viewModels[0].didTapDeleteButton()
        let alert = try XCTUnwrap(wireframe.sheets.last)
        XCTAssertEqual(alert.message, "custom")
        XCTAssertEqual(alert.title, R.string.localizable.nodeSelectionDeleteNodeTitle(preferredLanguages: CovJNetFixture.locale.rLanguages))
        XCTAssertTrue(interactor.deleted.isEmpty)
        alert.actions.first?.handler?()
        XCTAssertEqual(interactor.deleted, [custom])
    }
}

final class CovJNetNodeSelectionInteractorTests: XCTestCase {
    private let alpha = CovJNetFixture.node("alpha")
    private let custom = CovJNetFixture.node("custom")
    private let spare = CovJNetFixture.node("spare")

    private struct Fixture {
        let interactor: NodeSelectionInteractor
        let output: CovJNetNodeOutput
        let store: CovJNetChainStore
        let events: CovJNetEventCenterSpy
        let registry: CovJNetChainRegistryStub
    }

    private func makeFixture(chain: ChainModel) -> Fixture {
        let store = CovJNetChainStore()
        let events = CovJNetEventCenterSpy()
        let registry = CovJNetChainRegistryStub()
        let interactor = NodeSelectionInteractor(
            chain: chain,
            repository: AsyncAnyRepository(store),
            eventCenter: events,
            chainRegistry: registry
        )
        let output = CovJNetNodeOutput()
        interactor.presenter = output
        return Fixture(interactor: interactor, output: output, store: store, events: events, registry: registry)
    }

    func testSetupPublishesChainAndSelectionSavesResetsAndNotifies() throws {
        let chain = CovJNetFixture.chain(name: "Select", nodes: [alpha], custom: [custom])
        let fixture = makeFixture(chain: chain)

        fixture.interactor.setup()
        XCTAssertTrue(fixture.output.chains.first === chain)
        XCTAssertEqual(fixture.events.addedQueues.count, 1)

        fixture.interactor.selectNode(custom)
        XCTAssertEqual(fixture.registry.resets, [chain.chainId])
        XCTAssertTrue(CovJWait.until { fixture.events.chainUpdates.count == 1 })
        XCTAssertEqual(fixture.store.saved.map(\.selectedNode), [custom])
        XCTAssertEqual(fixture.events.chainUpdates.first?.updatedChains.first?.selectedNode, custom)
        XCTAssertEqual(fixture.interactor.chain.selectedNode, custom)

        fixture.interactor.setAutomaticSwitchNodes(true)
        XCTAssertTrue(CovJWait.until { fixture.events.chainUpdates.count == 2 })
        XCTAssertNil(fixture.store.saved.last?.selectedNode)

        fixture.interactor.setAutomaticSwitchNodes(false)
        XCTAssertTrue(CovJWait.until { fixture.events.chainUpdates.count == 3 })
        XCTAssertEqual(fixture.store.saved.last?.selectedNode, alpha)
        XCTAssertEqual(fixture.registry.resets.count, 3)
    }

    func testDeletingRemovesOnlyThatCustomNode() throws {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Delete", nodes: [alpha], custom: [custom, spare]))

        fixture.interactor.deleteNode(custom)
        XCTAssertTrue(CovJWait.until { fixture.events.chainUpdates.count == 1 })
        XCTAssertEqual(fixture.store.saved.first?.customNodes, [spare])
        XCTAssertEqual(fixture.interactor.chain.customNodes, [spare])
        XCTAssertTrue(fixture.registry.resets.isEmpty)
    }

    func testDeletingWithoutCustomNodesSavesNothing() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Plain", nodes: [alpha]))

        fixture.interactor.deleteNode(alpha)
        CovJWait.drain(0.2)

        XCTAssertTrue(fixture.store.saved.isEmpty)
        XCTAssertTrue(fixture.events.events.isEmpty)
    }

    func testChainUpdateEventsRefreshOnlyTheSameChain() {
        let chain = CovJNetFixture.chain(name: "Watched", nodes: [alpha])
        let fixture = makeFixture(chain: chain)
        fixture.interactor.setup()

        fixture.interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [CovJNetFixture.chain(name: "Other")]))
        CovJWait.drain(0.1)
        XCTAssertEqual(fixture.output.chains.count, 1)

        let updated = chain.replacingSelectedNode(alpha)
        fixture.interactor.processChainsUpdated(event: ChainsUpdatedEvent(updatedChains: [updated]))
        XCTAssertTrue(fixture.interactor.chain === updated)
        XCTAssertTrue(CovJWait.until { fixture.output.chains.count == 2 })
        XCTAssertTrue(fixture.output.chains.last === updated)
    }
}

final class CovJNetNodeSelectionWireframeTests: XCTestCase {
    func testNodeInfoOpensInNavigationAndAddNodeOpensForm() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let node = CovJNetFixture.node("alpha")
        let chain = CovJNetFixture.chain(name: "Wired", nodes: [node])
        let wireframe = NodeSelectionWireframe()

        wireframe.presentNodeInfo(chain: chain, node: node, mode: .none, from: host)
        XCTAssertTrue(CovJWait.until { host.presented != nil && host.presented?.isBeingPresented == false })
        let navigation = try XCTUnwrap(host.presented as? FearlessNavigationController)
        let info = try XCTUnwrap(navigation.viewControllers.first as? NetworkInfoViewController)
        let fields = CovJViewFixture.descendants(AnimatedTextField.self, in: info.view)
        XCTAssertTrue(fields.contains { $0.text == "alpha" })
        XCTAssertTrue(fields.allSatisfy { !$0.isUserInteractionEnabled })

        host.controller.dismiss(animated: false)
        XCTAssertTrue(CovJWait.until { host.presented == nil })

        wireframe.presentAddNodeFlow(with: chain, moduleOutput: nil, from: host)
        XCTAssertTrue(CovJWait.until { host.presented != nil && host.presented?.isBeingPresented == false })
        let form = try XCTUnwrap(host.presented as? AddCustomNodeViewController)
        XCTAssertFalse(form.rootView.addNodeButton.isEnabled)
        XCTAssertEqual(form.rootView.nodeNameInputView.animatedInputField.text, "")
    }
}

final class CovJNetNodeSelectionModuleTests: XCTestCase {
    func testControllerWithRealPresenterAndInteractorListsNodesAndSavesChoices() throws {
        let alpha = CovJNetFixture.node("alpha")
        let beta = CovJNetFixture.node("beta")
        let chain = CovJNetFixture.chain(name: "Module", nodes: [alpha, beta], selected: alpha)
        let store = CovJNetChainStore()
        let registry = CovJNetChainRegistryStub()
        let interactor = NodeSelectionInteractor(
            chain: chain,
            repository: AsyncAnyRepository(store),
            eventCenter: CovJNetEventCenterSpy(),
            chainRegistry: registry
        )
        let wireframe = CovJNetNodeWireframe()
        let presenter = NodeSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: NodeSelectionViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )
        let controller = NodeSelectionViewController(presenter: presenter)
        presenter.view = controller
        interactor.presenter = presenter
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let root = controller.rootView
        let table = root.tableView

        XCTAssertEqual(controller.locale, CovJNetFixture.locale)
        XCTAssertEqual(controller.numberOfSections(in: table), 1)
        XCTAssertEqual(controller.tableView(table, numberOfRowsInSection: 0), 2)
        XCTAssertEqual(root.navigationTitleLabel.text, "Module")
        XCTAssertTrue(root.editButton.isHidden)
        XCTAssertFalse(root.switchView.isOn)
        let first = try XCTUnwrap(controller.tableView(table, cellForRowAt: IndexPath(row: 0, section: 0)) as? NodeSelectionTableCell)
        XCTAssertEqual(first.nodeNameLabel.text, "alpha")
        XCTAssertFalse(first.selectedIconImageView.isHidden)

        controller.tableView(table, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(registry.resets, [chain.chainId])
        XCTAssertTrue(CovJWait.until { store.saved.count == 1 })
        XCTAssertEqual(store.saved.first?.selectedNode, beta)

        root.switchView.isOn = true
        root.switchView.sendActions(for: .valueChanged)
        XCTAssertTrue(CovJWait.until { store.saved.count == 2 })
        XCTAssertNil(store.saved.last?.selectedNode)
        XCTAssertEqual(registry.resets.count, 2)

        root.addNodeButton.sendActions(for: .touchUpInside)
        root.navigationBar.backButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(wireframe.addFlows.map(\.0), [chain.chainId])
        XCTAssertEqual(wireframe.dismissals, 1)
    }
}
