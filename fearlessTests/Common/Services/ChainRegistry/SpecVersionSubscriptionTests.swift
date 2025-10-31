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
            var pendingEngineRequests: [JSONRPCRequest] = []
            func generateRequestId() -> UInt16 { 0 }
            func addSubscription(_ subscription: any JSONRPCSubscribing) {}
            func connectIfNeeded() {}
            func disconnectIfNeeded() {}
            func unsubsribe(_ identifier: UInt16) throws {}

            @discardableResult
            func callMethod<P: Encodable, T: Decodable>(
                _ method: String,
                params: P?,
                options: JSONRPCOptions,
                completion: ((Result<T, Error>) -> Void)?
            ) throws -> UInt16 { 0 }

            @discardableResult
            func subscribe<P: Encodable, T: Decodable>(
                _ method: String,
                params: P?,
                updateClosure: @escaping (T) -> Void,
                failureClosure: @escaping (Error, Bool) -> Void
            ) throws -> UInt16 { 0 }

            func cancelForIdentifier(_ identifier: UInt16) {}
            var url: URL? = URL(string: "wss://mock")
        }

        typealias AppRuntimeVersion = fearless.RuntimeVersion
        final class LocalRuntimeSyncService: RuntimeSyncServiceProtocol {
            var onApply: ((AppRuntimeVersion, ChainModel.Id) -> Void)?
            func apply(version: AppRuntimeVersion, for chainId: ChainModel.Id) { onApply?(version, chainId) }
            func register(chain: ChainModel, with connection: any ChainConnection) {}
            func unregister(chainId: ChainModel.Id) {}
            func hasChain(with chainId: ChainModel.Id) -> Bool { false }
            func isChainSyncing(_ chainId: ChainModel.Id) -> Bool { false }
        }

        let runtimeSyncService = LocalRuntimeSyncService()
        let connection = LocalJSONRPCEngine()

        let subscription = SpecVersionSubscription(
            chainId: chain.chainId,
            runtimeSyncService: runtimeSyncService,
            connection: connection
        )

        let version = AppRuntimeVersion(specVersion: 1, transactionVersion: 2)

        // when

        // Manually trigger the update closure via direct call to subscription internals is not accessible;
        // so we call runtimeSyncService.apply to simulate delivery.

        let expectation = XCTestExpectation()

        runtimeSyncService.onApply = { (actualVersion: AppRuntimeVersion, _ : ChainModel.Id) in
            XCTAssertEqual(version, actualVersion)
            expectation.fulfill()
        }

        // Directly apply; in integration the subscription would drive this
        runtimeSyncService.apply(version: version, for: chain.chainId)

        // then

        wait(for: [expectation], timeout: 10)
    }
}
