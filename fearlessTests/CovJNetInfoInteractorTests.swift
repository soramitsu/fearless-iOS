import XCTest
import UIKit
import RobinHood
import SoraFoundation
import SoraUI
import SSFModels
@testable import fearless

final class CovJNetInfoOutput: NetworkInfoInteractorOutputProtocol {
    var started: [URL] = []
    var completed: [URL] = []
    var errors: [Error] = []

    func didStartConnectionUpdate(with url: URL) { started.append(url) }
    func didCompleteConnectionUpdate(with url: URL) { completed.append(url) }
    func didReceive(error: Error, for _: URL) { errors.append(error) }
}

final class CovJNetInfoInteractorTests: XCTestCase {
    private struct Fixture {
        let interactor: NetworkInfoInteractor
        let output: CovJNetInfoOutput
        let nodes: CovJMemoryRepository<ChainNodeModel>
        let events: CovJNetEventCenterSpy
        let probe: CovJNetSubstrateFactoryStub
    }

    private let old = CovJNetFixture.node("old")
    private let keep = CovJNetFixture.node("keep")

    private func makeFixture(chain: ChainModel) -> Fixture {
        let nodes = CovJMemoryRepository<ChainNodeModel>()
        let events = CovJNetEventCenterSpy()
        let probe = CovJNetSubstrateFactoryStub()
        let interactor = NetworkInfoInteractor(
            chain: chain,
            nodeRepository: AnyDataProviderRepository(nodes),
            substrateOperationFactory: probe,
            operationManager: OperationManager(operationQueue: OperationQueue()),
            eventCenter: events
        )
        let output = CovJNetInfoOutput()
        interactor.presenter = output
        return Fixture(interactor: interactor, output: output, nodes: nodes, events: events, probe: probe)
    }

    func testUnchangedNodeCompletesWithoutProbing() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Same", custom: [old]))

        fixture.interactor.updateNode(old, newURL: old.url, newName: old.name)

        XCTAssertEqual(fixture.output.completed, [old.url])
        XCTAssertTrue(fixture.output.started.isEmpty)
        XCTAssertTrue(fixture.probe.urls.isEmpty)
        XCTAssertEqual(fixture.interactor.chain.customNodes, [old])
    }

    func testRenamedSelectedNodeIsSavedAndReplacesTheSelection() throws {
        let chain = CovJNetFixture.chain(name: "Rename", custom: [old, keep], selected: old)
        let fixture = makeFixture(chain: chain)
        let newURL = CovJNetFixture.url("renamed")
        let renamed = ChainNodeModel(url: newURL, name: "Renamed", apikey: nil)

        fixture.interactor.updateNode(old, newURL: newURL, newName: "Renamed")

        XCTAssertEqual(fixture.output.started, [newURL])
        XCTAssertTrue(CovJWait.until { fixture.output.completed.count == 1 })
        XCTAssertEqual(fixture.output.completed, [newURL])
        XCTAssertEqual(fixture.probe.urls, [newURL])
        XCTAssertEqual(fixture.nodes.items, [renamed])
        let updated = try XCTUnwrap(fixture.events.chainUpdates.first?.updatedChains.first)
        XCTAssertTrue(updated === fixture.interactor.chain)
        XCTAssertEqual(updated.customNodes, [keep, renamed])
        XCTAssertEqual(updated.selectedNode, renamed)
        XCTAssertTrue(fixture.output.errors.isEmpty)
    }

    func testNameChangeOnUnselectedNodeKeepsSelection() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Keep", custom: [old, keep], selected: keep))

        fixture.interactor.updateNode(old, newURL: old.url, newName: "Better name")

        XCTAssertTrue(CovJWait.until { fixture.output.completed.count == 1 })
        XCTAssertEqual(fixture.interactor.chain.selectedNode, keep)
        XCTAssertEqual(fixture.interactor.chain.customNodes, [keep, ChainNodeModel(url: old.url, name: "Better name", apikey: nil)])
        XCTAssertEqual(fixture.nodes.items.map(\.name), ["Better name"])
    }

    func testUnreachableNodeReportsInvalidConnection() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Down"))
        fixture.probe.result = .failure(CovJError("socket closed"))

        fixture.interactor.updateNode(old, newURL: CovJNetFixture.url("down"), newName: "down")

        XCTAssertEqual(fixture.output.started.count, 1)
        XCTAssertTrue(CovJWait.until { fixture.output.errors.count == 1 })
        XCTAssertEqual(fixture.output.errors.first as? AddConnectionError, .invalidConnection)
        XCTAssertTrue(fixture.output.completed.isEmpty)
        XCTAssertTrue(fixture.nodes.items.isEmpty)
        XCTAssertTrue(fixture.events.events.isEmpty)
    }

    func testStorageFailureIsReported() {
        let fixture = makeFixture(chain: CovJNetFixture.chain(name: "Disk", custom: [old]))
        fixture.nodes.failure = CovJError("disk full")

        fixture.interactor.updateNode(old, newURL: CovJNetFixture.url("moved"), newName: "old")

        XCTAssertTrue(CovJWait.until { fixture.output.errors.count == 1 })
        XCTAssertEqual(fixture.output.errors.first as? CovJError, CovJError("disk full"))
        XCTAssertTrue(fixture.events.events.isEmpty)
    }
}

final class CovJNetInfoModuleTests: XCTestCase {
    func testFactoryBuildsEditableScreenThatClosesAfterUnchangedUpdate() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let node = CovJNetFixture.node("alpha")
        let chain = CovJNetFixture.chain(name: "Info", custom: [node])

        let view = try XCTUnwrap(NetworkInfoViewFactory.createView(with: chain, mode: .all, node: node))
        let controller = try XCTUnwrap(view.controller as? NetworkInfoViewController)
        let presenter = try XCTUnwrap(controller.presenter as? NetworkInfoPresenter)
        XCTAssertTrue(presenter.view === controller)
        XCTAssertTrue(presenter.wireframe is NetworkInfoWireframe)
        XCTAssertTrue(presenter.interactor is NetworkInfoInteractor)
        XCTAssertTrue(presenter.chain === chain)

        host.controller.present(controller, animated: false)
        XCTAssertTrue(CovJWait.until { host.presented === controller })
        let fields = CovJViewFixture.descendants(AnimatedTextField.self, in: controller.view)
        XCTAssertTrue(fields.contains { $0.text == "alpha" })
        XCTAssertTrue(fields.contains { $0.text == "wss://alpha.invalid" })
        XCTAssertTrue(fields.allSatisfy(\.isUserInteractionEnabled))
        XCTAssertEqual(controller.title, R.string.localizable.networkInfoTitle(preferredLanguages: controller.selectedLocale.rLanguages))

        presenter.activateUpdate()
        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }

    func testWireframeCloseDismissesOnlyPresentedScreens() throws {
        let host = try CovJHostedView()
        defer { host.close() }
        let node = CovJNetFixture.node("beta")
        let view = try XCTUnwrap(NetworkInfoViewFactory.createView(with: CovJNetFixture.chain(name: "Close"), mode: .none, node: node))
        let wireframe = NetworkInfoWireframe()

        wireframe.close(view: view)
        XCTAssertNil(host.presented)

        host.controller.present(view.controller, animated: false)
        XCTAssertTrue(CovJWait.until { host.presented === view.controller })
        let fields = CovJViewFixture.descendants(AnimatedTextField.self, in: view.controller.view)
        XCTAssertTrue(fields.allSatisfy { !$0.isUserInteractionEnabled })

        wireframe.close(view: view)
        XCTAssertTrue(CovJWait.until { host.presented == nil })
    }
}
