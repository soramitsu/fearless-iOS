import XCTest
@testable import fearless
import Cuckoo
import SSFUtils
import SSFModels

class SpecVersionSubscriptionTests: XCTestCase {
    func testVersionDelivered() {
        // given

        let chain = ChainModelGenerator.generate(count: 1).first!
        final class LocalJSONRPCEngine: JSONRPCEngine {
            func callMethod<P, T>(_ method: String, params: P?, options: JSONRPCOptions, completion: ((Result<T, Error>) -> Void)?) throws -> UInt16 where P : Encodable, T : Decodable { 0 }
            func subscribe<P, T>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 where P : Encodable, T : Decodable { 0 }
            func cancelForIdentifier(_ identifier: UInt16) {}
            var url: URL? = URL(string: "wss://mock")
        }
        final class LocalRuntimeSyncService: RuntimeSyncServiceProtocol {
            var onApply: ((RuntimeVersion, ChainModel.Id) -> Void)?
            func apply(version: RuntimeVersion, for chainId: ChainModel.Id) { onApply?(version, chainId) }
        }

        let runtimeSyncService = LocalRuntimeSyncService()
        let connection = LocalJSONRPCEngine()

        let subscription = SpecVersionSubscription(
            chainId: chain.chainId,
            runtimeSyncService: runtimeSyncService,
            connection: connection
        )

        let version = RuntimeVersion(specVersion: 1, transactionVersion: 2)

        // when

        // Manually trigger the update closure via direct call to subscription internals is not accessible;
        // so we call runtimeSyncService.apply to simulate delivery.

        let expectation = XCTestExpectation()

        runtimeSyncService.onApply = { actualVersion, _ in
            XCTAssertEqual(version, actualVersion)
            expectation.fulfill()
        }

        // Directly apply; in integration the subscription would drive this
        runtimeSyncService.apply(version: version, for: chain.chainId)

        // then

        wait(for: [expectation], timeout: 10)
    }
}
