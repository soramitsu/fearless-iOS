import XCTest
import RobinHood
import SSFModels
@testable import fearless

/// The save of a new custom node reads the duplicate check's result, but only waited for the reachability probe. On
/// the concurrent transient queue a probe that answered before the duplicate check finished made the save fail with
/// parentOperationCancelled, and the user saw an error for a node that could be added.
final class AddCustomNodeDuplicateCheckOrderTests: XCTestCase {
    func testTheSaveWaitsForASlowDuplicateCheck() {
        let chain = CovJNetFixture.chain(name: "Slow check", nodes: [CovJNetFixture.node("alpha")])
        let chains = CovJMemoryRepository<ChainModel>()
        let nodes = CovJMemoryRepository<ChainNodeModel>()
        let node = CovJNetFixture.node("mine")
        let operationManager = SlowDuplicateCheckOperationManager()
        let interactor = AddCustomNodeInteractor(
            chain: chain,
            repository: AnyDataProviderRepository(chains),
            nodeRepository: AnyDataProviderRepository(nodes),
            operationManager: operationManager,
            eventCenter: CovJNetEventCenterSpy(),
            substrateOperationFactory: CovJNetSubstrateFactoryStub()
        )
        let output = CovJNetAddNodeOutput()
        interactor.presenter = output

        interactor.addConnection(url: node.url, name: "mine")

        XCTAssertTrue(CovJWait.until(timeout: 5) { output.completed.count + output.errors.count == 1 })
        // The memory repository's operations hold it unowned: let the late lookup finish while it still exists.
        XCTAssertTrue(CovJWait.until(timeout: 5) { operationManager.lookupsFinished })
        XCTAssertTrue(output.errors.isEmpty, "\(output.errors)")
        XCTAssertEqual(output.completed, [node.url])
        XCTAssertEqual(chains.items.first?.customNodes, [node])
        withExtendedLifetime((interactor, nodes)) {}
    }
}

/// Runs the operations on a concurrent queue, starting the stored-node lookup only after the others had time to run:
/// the order a slow store and a fast node give in the app.
private final class SlowDuplicateCheckOperationManager: OperationManagerProtocol {
    private let queue = OperationQueue()
    private let lock = NSLock()
    private var lookups: [Operation] = []

    var lookupsFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !lookups.isEmpty && lookups.allSatisfy(\.isFinished)
    }

    func enqueue(operations: [Operation], in _: OperationMode) {
        let delayed = operations.filter { $0 is BaseOperation<ChainNodeModel?> }
        let others = operations.filter { !($0 is BaseOperation<ChainNodeModel?>) }
        lock.lock()
        lookups += delayed
        lock.unlock()
        queue.addOperations(others, waitUntilFinished: false)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { [queue] in
            queue.addOperations(delayed, waitUntilFinished: false)
        }
    }
}
