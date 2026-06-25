import XCTest
@testable import fearless

final class IrohaToriiClientTests: XCTestCase {
    func testDelegatesReadEndpointsThroughValidatedToriiRoutes() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Self.accountListJSON)
        _ = try await client.accounts(limit: 50, offset: 10, countMode: .exact)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://taira.sora.org/v1/accounts?limit=50&offset=10&count_mode=exact"
        )
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.accountAssetsJSON)
        _ = try await client.accountAssets(
            accountID: Self.account,
            limit: 25,
            countMode: .bounded,
            asset: "xor#sora",
            scope: "global"
        )
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/assets?limit=25&count_mode=bounded&asset=xor%23sora&scope=global"
        )

        transport.enqueue(Self.transactionStatusJSON)
        _ = try await client.transactionStatus(hash: Self.hash, scope: .global)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://taira.sora.org/v1/pipeline/transactions/status?hash=\(Self.hash)&scope=global"
        )
    }

    func testDelegatesMCPAndTransactionWritesWithExplicitTransportContracts() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Self.transactionReceiptJSON)
        _ = try await client.submitTransaction(noritoBytes: Data([1, 2, 3]))
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://taira.sora.org/v1/pipeline/transactions")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/x-norito")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(transport.lastRequest?.httpBody, Data([1, 2, 3]))

        transport.enqueue(Self.mcpResponseJSON)
        _ = try await client.mcpJSONRPC(
            try IrohaToriiRoutes.mcpJSONRPCRequest(method: "tools/list", id: "1")
        )
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://taira.sora.org/v1/mcp")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNotNil(transport.lastRequest?.httpBody)
    }

    func testUsesMinamotoForNexusByDefaultAndAllowsRuntimeOverride() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        transport.enqueue(Data("{}".utf8))
        _ = try await client.mcpCapabilities(network: UniversalWalletRegistry.nexus)
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://minamoto.sora.org/v1/mcp")

        transport.enqueue(Data("{}".utf8))
        _ = try await client.mcpCapabilities(
            network: UniversalWalletRegistry.nexus,
            baseURL: "https://nexus.example"
        )
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://nexus.example/v1/mcp")
    }

    func testRejectsWrongNetworkIrohaAccountIDsBeforeFetch() async throws {
        let transport = FakeIrohaToriiTransport()
        let client = IrohaToriiClient(transport: transport)

        do {
            _ = try await client.account(accountID: Self.nexusAccount)
            XCTFail("Expected Nexus account to be rejected for default Taira reads")
        } catch {
            XCTAssertEqual(error as? IrohaAddressError, IrohaAddressError(code: .unexpectedNetworkPrefix))
            XCTAssertNil(transport.lastRequest)
        }

        transport.enqueue(Self.accountListItemJSON(account: Self.nexusAccount))
        _ = try await client.account(
            accountID: Self.nexusAccount,
            baseURL: "https://nexus.example",
            network: UniversalWalletRegistry.nexus
        )
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://nexus.example/v1/accounts/\(Self.encodedNexusAccount)"
        )
    }

    private final class FakeIrohaToriiTransport: UniversalWalletHTTPTransport {
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

    private static let account = "testuﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
    private static let encodedAccount = "testu%EF%BE%9B1Pc%EF%BE%852%EF%BE%97t%EF%BE%89a%EF%BE%98L%EF%BE%95%EF%BD%BD2M%E3%83%B1%EF%BE%90%EF%BE%8E%EF%BD%B3%EF%BE%93%E3%83%B1%EF%BD%B7%EF%BE%86%EF%BD%B2M%EF%BE%92S%EF%BE%8F%EF%BD%B1%E3%83%B1%EF%BD%B7J%E3%83%B1FmJ%EF%BE%87Ms6YN687Y"
    private static let nexusAccount = "sorauﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱｷﾆｲMﾒSﾏｱヱｷJヱFmJﾇMs6YN687Y"
    private static let encodedNexusAccount = "sorau%EF%BE%9B1Pc%EF%BE%852%EF%BE%97t%EF%BE%89a%EF%BE%98L%EF%BE%95%EF%BD%BD2M%E3%83%B1%EF%BE%90%EF%BE%8E%EF%BD%B3%EF%BE%93%E3%83%B1%EF%BD%B7%EF%BE%86%EF%BD%B2M%EF%BE%92S%EF%BE%8F%EF%BD%B1%E3%83%B1%EF%BD%B7J%E3%83%B1FmJ%EF%BE%87Ms6YN687Y"
    private static let hash = String(repeating: "a", count: 64)

    private static let accountListJSON = Data("""
    {
      "items": [{ "id": "\(account)" }],
      "has_more": false,
      "count_mode": "exact",
      "total": 1
    }
    """.utf8)

    private static func accountListItemJSON(account: String) -> Data {
        Data("""
        {
          "id": "\(account)"
        }
        """.utf8)
    }

    private static let accountAssetsJSON = Data("""
    {
      "items": [
        {
          "account_id": "\(account)",
          "asset": "xor#sora",
          "quantity": "340282366920938463463374607431768211455",
          "scope": "global"
        }
      ],
      "has_more": false,
      "count_mode": "bounded"
    }
    """.utf8)

    private static let transactionStatusJSON = Data("""
    {
      "hash": "\(hash)",
      "status": {
        "kind": "committed",
        "block_height": 42
      },
      "scope": "global",
      "resolved_from": "pipeline"
    }
    """.utf8)

    private static let transactionReceiptJSON = Data("""
    {
      "payload": {
        "tx_hash": "\(hash)",
        "entrypoint_hash": "\(hash)",
        "submitted_at_ms": 1,
        "submitted_at_height": 1
      }
    }
    """.utf8)

    private static let mcpResponseJSON = Data("""
    {
      "jsonrpc": "2.0",
      "id": "1",
      "result": {
        "ok": true
      }
    }
    """.utf8)
}
