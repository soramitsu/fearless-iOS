import XCTest
@testable import fearless

final class TonIndexerClientTests: XCTestCase {
    func testDelegatesAccountEndpointsThroughValidatedTONIndexerRoutes() async throws {
        let transport = FakeTonIndexerTransport()
        let client = TonIndexerClient(transport: transport)

        transport.enqueue(Self.serviceInfoJSON)
        _ = try await client.verifyServiceInfo()
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://ti.soramitsu.io/api/indexer/v1/service-info")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.balanceJSON)
        _ = try await client.balance(address: Self.address)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/balance"
        )
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.transactionsJSON)
        _ = try await client.transactions(
            address: Self.address,
            page: 2,
            cursorLt: "10",
            cursorHash: Self.hash
        )
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/txs?page=2&cursor_lt=10&cursor_hash=\(Self.encodedHash)"
        )

        transport.enqueue(Self.swapsJSON)
        _ = try await client.swaps(
            address: Self.address,
            limit: 25,
            fromUtime: 100,
            toUtime: 200,
            payToken: "TON",
            receiveToken: "TST",
            executionType: .market,
            status: .success,
            includeReverse: true
        )
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/swaps?limit=25&from_utime=100&to_utime=200&pay_token=TON&receive_token=TST&execution_type=market&status=success&include_reverse=true"
        )

        transport.enqueue(Self.payloadJSON)
        _ = try await client.jettonTransferPayload(jetton: Self.address, owner: Self.rawAddress.uppercased())
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/jettons/\(Self.address)/transfer/\(Self.rawAddress)/payload"
        )
    }

    func testDelegatesGetterCallsWithNormalizedRequestBodies() async throws {
        let transport = FakeTonIndexerTransport()
        let client = TonIndexerClient(transport: transport)

        transport.enqueue(Self.runGetMethodJSON)
        _ = try await client.runGetMethod(address: Self.address, method: " seqno ")
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://ti.soramitsu.io/api/indexer/v1/runGetMethod")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNotNil(transport.lastRequest?.httpBody)

        let call = try TonIndexerRoutes.runGetMethodRequest(address: Self.address, method: "seqno")
        transport.enqueue(Self.runGetMethodsJSON)
        _ = try await client.runGetMethods(calls: [call])
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://ti.soramitsu.io/api/indexer/v1/runGetMethods")

        do {
            _ = try await client.runGetMethod(address: Self.address, method: "bad-method")
            XCTFail("Expected invalid getter method to be rejected")
        } catch {
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidMethod)
        }

        do {
            _ = try await client.runGetMethods(calls: [])
            XCTFail("Expected empty getter batch to be rejected")
        } catch {
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidCalls)
        }
    }

    func testVerifyServiceInfoRejectsMisroutedTONIndexer() async throws {
        let transport = FakeTonIndexerTransport()
        let client = TonIndexerClient(transport: transport)

        transport.enqueue(Self.misroutedServiceInfoJSON)

        do {
            _ = try await client.verifyServiceInfo()
            XCTFail("Expected misrouted TON service info to be rejected")
        } catch {
            XCTAssertEqual(
                error as? TonIndexerClientError,
                .unexpectedServiceInfo(Self.misroutedServiceInfo)
            )
            XCTAssertEqual(
                transport.lastRequest?.url?.absoluteString,
                "https://ti.soramitsu.io/api/indexer/v1/service-info"
            )
        }
    }

    private final class FakeTonIndexerTransport: UniversalWalletHTTPTransport {
        private var queuedResponses: [Data] = []
        private(set) var lastRequest: URLRequest?

        func enqueue(_ data: Data) {
            queuedResponses.append(data)
        }

        func perform(_ request: URLRequest) async throws -> Data {
            lastRequest = request
            return queuedResponses.isEmpty ? Data("{}".utf8) : queuedResponses.removeFirst()
        }
    }

    private static let address = "UQDxAUFadQXDd3EXGa3TLF_EF66gMc9h3_aZ0j0zXNoIYUCc"
    private static let rawAddress = "0:f101415a7505c377711719add32c5fc417aea031cf61dff699d23d335cda0861"
    private static let hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    private static let encodedHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%3D"

    private static let serviceInfoJSON = Data("""
    {
      "schemaVersion": 1,
      "serviceId": "ti.soramitsu.io",
      "serviceName": "TON Indexer",
      "ecosystem": "ton",
      "chainId": "ton:mainnet",
      "network": "mainnet",
      "publicBaseUrl": "https://ti.soramitsu.io",
      "readOnly": true,
      "capabilities": ["account-transactions"],
      "endpoints": {
        "transactions": "/api/indexer/v1/accounts/{addr}/txs"
      }
    }
    """.utf8)

    private static let misroutedServiceInfoJSON = Data("""
    {
      "schemaVersion": 1,
      "serviceId": "si.soramitsu.io",
      "serviceName": "Solswap Indexer",
      "ecosystem": "solana",
      "chainId": "solana:mainnet",
      "network": "mainnet",
      "publicBaseUrl": "https://si.soramitsu.io",
      "readOnly": true,
      "capabilities": ["wallet-transactions"],
      "endpoints": {
        "transactions": "/api/indexer/v1/accounts/{wallet}/txs"
      }
    }
    """.utf8)

    private static let misroutedServiceInfo = TonIndexerServiceInfo(
        schemaVersion: 1,
        serviceId: "si.soramitsu.io",
        serviceName: "Solswap Indexer",
        ecosystem: "solana",
        chainId: "solana:mainnet",
        network: "mainnet",
        publicBaseUrl: "https://si.soramitsu.io",
        readOnly: true,
        capabilities: ["wallet-transactions"],
        endpoints: ["transactions": "/api/indexer/v1/accounts/{wallet}/txs"]
    )

    private static let balanceJSON = Data("""
    {
      "ton": {
        "balance": "0"
      },
      "jettons": [],
      "confirmed": true,
      "updated_at": 1,
      "network": "mainnet"
    }
    """.utf8)

    private static let transactionsJSON = Data("""
    {
      "page": 1,
      "page_size": 0,
      "total_txs": 0,
      "total_pages_min": 0,
      "history_complete": true,
      "txs": [],
      "network": "mainnet"
    }
    """.utf8)

    private static let swapsJSON = Data("""
    {
      "address": "\(address)",
      "swaps": [],
      "count": 0,
      "network": "mainnet"
    }
    """.utf8)

    private static let payloadJSON = Data("""
    {
      "custom_payload": null,
      "state_init": null
    }
    """.utf8)

    private static let runGetMethodJSON = Data("""
    {
      "exit_code": 0,
      "gas_used": 0,
      "stack": []
    }
    """.utf8)

    private static let runGetMethodsJSON = Data("""
    {
      "results": []
    }
    """.utf8)
}
