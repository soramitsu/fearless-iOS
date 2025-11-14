import XCTest
@testable import fearless
import Cuckoo
import SSFUtils

class SpecVersionSubscriptionTests: XCTestCase {
    func testVersionDelivered() {
        // given

        let chain = ChainModelGenerator.generate(count: 1).first!
        let runtimeSyncService = MockRuntimeSyncServiceProtocol()
        let connection = RuntimeVersionJSONRPCEngineStub()

        let subscription = SpecVersionSubscription(
            chainId: chain.chainId,
            runtimeSyncService: runtimeSyncService,
            connection: connection
        )

        let version = RuntimeVersion(specVersion: 1, transactionVersion: 2)

        // when

        let expectation = XCTestExpectation()

        stub(runtimeSyncService) { stub in
            stub.apply(version: any(), for: any()).then { actualVersion, chainId in
                XCTAssertEqual(version, actualVersion)
                expectation.fulfill()
            }
        }

        subscription.subscribe()

        DispatchQueue.global().async {
            let update = RuntimeVersionUpdate(
                jsonrpc: "2.0",
                method: RPCMethod.runtimeVersionSubscribe,
                params: JSONRPCSubscriptionUpdate.Result(
                    result: version,
                    subscription: ""
                )
            )

            connection.emit(update: update)
        }

        // then

        wait(for: [expectation], timeout: 10)
    }
}

private final class RuntimeVersionJSONRPCEngineStub: JSONRPCEngine {
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private var updateHandler: ((RuntimeVersionUpdate) -> Void)?

    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw JSONRPCEngineError.clientCancelled
    }

    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        precondition(T.self == RuntimeVersionUpdate.self, "Unsupported subscription type \(T.self)")

        updateHandler = { update in
            updateClosure(update as! T) // swiftlint:disable:this force_cast
        }

        return 0
    }

    func cancelForIdentifier(_ identifier: UInt16) {}

    func generateRequestId() -> UInt16 { 0 }

    func addSubscription(_ subscription: JSONRPCSubscribing) {}

    func reconnect(url: URL) { self.url = url }

    func connectIfNeeded() {}

    func disconnectIfNeeded() {}

    func emit(update: RuntimeVersionUpdate) {
        updateHandler?(update)
    }
}
