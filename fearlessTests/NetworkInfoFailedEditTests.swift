import XCTest
import RobinHood
import SSFModels
@testable import fearless

/// NetworkInfoInteractor applied a node edit to its chain before the node was probed and saved. After a failed
/// edit the screen stays open; the next attempt started from the failed edit, so the chain it announced kept the
/// unreachable node, and when the edited node was in use, the unreachable node stayed selected.
final class NetworkInfoFailedEditTests: XCTestCase {
    private let old = CovJNetFixture.node("old")
    private let keep = CovJNetFixture.node("keep")

    func testAFailedEditLeavesTheChainAsItWas() {
        let chain = CovJNetFixture.chain(name: "Failed edit", custom: [old, keep], selected: old)
        let (interactor, output, _, probe) = makeInteractor(chain: chain)
        probe.result = .failure(CovJError("socket closed"))

        interactor.updateNode(old, newURL: CovJNetFixture.url("down"), newName: "down")

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.errors.count == 1 })
        XCTAssertEqual(interactor.chain.customNodes, [old, keep])
        XCTAssertEqual(interactor.chain.selectedNode, old)
    }

    func testARetryAfterAFailedEditAnnouncesOnlyTheNodeThatWasSaved() throws {
        let chain = CovJNetFixture.chain(name: "Retry", custom: [old, keep], selected: old)
        let (interactor, output, events, probe) = makeInteractor(chain: chain)
        probe.result = .failure(CovJError("socket closed"))
        interactor.updateNode(old, newURL: CovJNetFixture.url("down"), newName: "down")
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.errors.count == 1 })

        // The screen still edits the node it was opened for.
        probe.result = .success("covjnet-genesis")
        let fixedURL = CovJNetFixture.url("fixed")
        interactor.updateNode(old, newURL: fixedURL, newName: "fixed")
        XCTAssertTrue(CovJWait.until(timeout: 5) { output.completed.count == 1 })

        let fixed = ChainNodeModel(url: fixedURL, name: "fixed", apikey: nil)
        let announced = try XCTUnwrap(events.chainUpdates.last?.updatedChains.first)
        XCTAssertEqual(announced.customNodes, [keep, fixed])
        XCTAssertEqual(announced.selectedNode, fixed)
        XCTAssertTrue(announced === interactor.chain)
    }

    private func makeInteractor(
        chain: ChainModel
    ) -> (NetworkInfoInteractor, CovJNetInfoOutput, CovJNetEventCenterSpy, CovJNetSubstrateFactoryStub) {
        let events = CovJNetEventCenterSpy()
        let probe = CovJNetSubstrateFactoryStub()
        let interactor = NetworkInfoInteractor(
            chain: chain,
            nodeRepository: AnyDataProviderRepository(CovJMemoryRepository<ChainNodeModel>()),
            substrateOperationFactory: probe,
            operationManager: OperationManager(operationQueue: OperationQueue()),
            eventCenter: events
        )
        let output = CovJNetInfoOutput()
        interactor.presenter = output
        return (interactor, output, events, probe)
    }
}
