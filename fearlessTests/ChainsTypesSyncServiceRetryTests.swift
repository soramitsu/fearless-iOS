import RobinHood
import SSFUtils
import XCTest
@testable import fearless

/// A chain types payload that cannot be parsed is a failed sync. It used to be only logged: the service stayed
/// "syncing" for good and never retried, so chain types did not sync again until the app restarted.
final class ChainsTypesSyncServiceRetryTests: XCTestCase {
    func testUnparsablePayloadEndsTheSyncAndIsRetried() throws {
        let data = CountingDataOperationFactory(payload: Data(#"{"not":"an array"}"#.utf8))
        let service = ChainsTypesSyncService(
            url: URL(string: "https://types.invalid/chains.json"),
            filesOperationFactory: MockRuntimeFilesOperationFactoryProtocol(),
            dataOperationFactory: data,
            eventCenter: EventCenterProtocolStub(),
            operationQueue: OperationQueue(),
            retryStrategy: ImmediateRetry(),
            logger: Logger.shared
        )

        service.syncUp()

        let retried = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in data.fetches >= 2 }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [retried], timeout: 10), .completed, "the failed sync is retried")
    }
}

private final class CountingDataOperationFactory: DataOperationFactoryProtocol {
    let payload: Data
    private let lock = NSLock()
    private var count = 0

    init(payload: Data) {
        self.payload = payload
    }

    var fetches: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func fetchData(from _: URL) -> BaseOperation<Data> {
        lock.lock()
        count += 1
        lock.unlock()
        let payload = payload
        return ClosureOperation { payload }
    }
}

private struct ImmediateRetry: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? {
        0.05
    }
}
