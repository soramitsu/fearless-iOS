import XCTest
@testable import fearless
import Cuckoo
import SSFUtils

class SpecVersionSubscriptionTests: XCTestCase {
    func testVersionDelivered() {
        // given

        let chain = ChainModelGenerator.generate(count: 1).first!
        let runtimeSyncService = MockRuntimeSyncServiceProtocol()
        let connection = MockConnection()

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

            connection.emit(update)
        }

        // then

        wait(for: [expectation], timeout: 10)
    }

    func testTonApiClientFactoryProvidesClient() {
        let tonApiURL = URL(string: "https://tonapi.example")!
        let tonApiClientFactory = TonAPIClientFactory(
            tonAPIURL: tonApiURL,
            token: "test-token"
        )

        _ = tonApiClientFactory.tonAPIClient()
    }
}
