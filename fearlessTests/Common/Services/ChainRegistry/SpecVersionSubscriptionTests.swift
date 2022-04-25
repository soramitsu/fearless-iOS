import XCTest
@testable import fearless
import Cuckoo
import FearlessUtils

class SpecVersionSubscriptionTests: XCTestCase {
    func testVersionDelivered() {
        // given

        let chain = ChainModelGenerator.generate(count: 1).first!
        let runtimeSyncService = MockRuntimeSyncServiceProtocol()
        let connection = MockJSONRPCEngine()

        let subscription = SpecVersionSubscription(
            chainId: chain.chainId,
            runtimeSyncService: runtimeSyncService,
            connection: connection
        )

        let version = RuntimeVersion(specVersion: 1, transactionVersion: 2)

        // when

        stub(connection) { stub in
            stub.subscribe(
                any(),
                params: any([String].self),
                updateClosure: any(),
                failureClosure: any()
            ).then { (_, _, updateClosure: @escaping (RuntimeVersionUpdate) -> Void, _) in
                DispatchQueue.global().async {
                    let update = RuntimeVersionUpdate(
                        jsonrpc: "2.0",
                        method: RPCMethod.runtimeVersionSubscribe,
                        params: JSONRPCSubscriptionUpdate.Result(
                            result: version,
                            subscription: ""
                        )
                    )

                    updateClosure(update)
                }

                return 0
            }
        }

        let expectation = XCTestExpectation()

        stub(runtimeSyncService) { stub in
            stub.apply(version: any(), for: any()).then { actualVersion, chainId in
                XCTAssertEqual(version, actualVersion)
                expectation.fulfill()
            }
        }

        subscription.subscribe()

        // then

        wait(for: [expectation], timeout: 10)
    }
}
