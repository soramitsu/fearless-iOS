import XCTest
@testable import fearless

final class SolanaIndexerClientTests: XCTestCase {
    func testDelegatesWalletEndpointsThroughValidatedSIRoutes() async throws {
        let transport = FakeSolanaIndexerTransport()
        let client = SolanaIndexerClient(transport: transport)

        transport.enqueue(Self.serviceInfoJSON)
        _ = try await client.verifyServiceInfo()
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://si.soramitsu.io/api/indexer/v1/service-info")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.balancesJSON)
        _ = try await client.balances(wallet: Self.wallet)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/accounts/\(Self.wallet)/balances"
        )
        XCTAssertEqual(transport.lastRequest?.httpMethod, "GET")

        transport.enqueue(Self.transactionsJSON)
        _ = try await client.transactions(wallet: Self.wallet, before: Self.signature, limit: 25)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/accounts/\(Self.wallet)/txs?limit=25&before=\(Self.signature)"
        )

        transport.enqueue(Self.metadataJSON)
        let metadata = try await client.tokenMetadata(mint: Self.mint)
        XCTAssertEqual(
            transport.lastRequest?.url?.absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/tokens/\(Self.mint)/metadata"
        )
        XCTAssertEqual(metadata.extensions, ["transferFeeConfig", "transferHook"])
        XCTAssertEqual(metadata.transferFeeConfig?.withheldAmount, "0")
        XCTAssertEqual(metadata.transferHook?.programId, Self.wallet)
        XCTAssertEqual(metadata.transferHook?.extraAccountMetasAddress, Self.wallet)
    }

    func testDelegatesMetadataBatchWithNormalizedRequestBody() async throws {
        let transport = FakeSolanaIndexerTransport()
        let client = SolanaIndexerClient(transport: transport)

        transport.enqueue(Self.metadataBatchJSON)
        _ = try await client.tokenMetadataBatch(mints: [Self.mint])
        XCTAssertEqual(transport.lastRequest?.url?.absoluteString, "https://si.soramitsu.io/api/indexer/v1/tokens/metadata")
        XCTAssertEqual(transport.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transport.lastRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNotNil(transport.lastRequest?.httpBody)

        do {
            _ = try await client.tokenMetadataBatch(mints: [])
            XCTFail("Expected empty metadata batch to be rejected")
        } catch {
            XCTAssertEqual(error as? SolanaIndexerRouteError, .invalidMints)
        }
    }

    func testVerifyServiceInfoRejectsMisroutedSolanaIndexer() async throws {
        let transport = FakeSolanaIndexerTransport()
        let client = SolanaIndexerClient(transport: transport)

        transport.enqueue(Self.misroutedServiceInfoJSON)

        do {
            _ = try await client.verifyServiceInfo()
            XCTFail("Expected misrouted SI service info to be rejected")
        } catch {
            XCTAssertEqual(
                error as? SolanaIndexerClientError,
                .unexpectedServiceInfo(Self.misroutedServiceInfo)
            )
            XCTAssertEqual(
                transport.lastRequest?.url?.absoluteString,
                "https://si.soramitsu.io/api/indexer/v1/service-info"
            )
        }
    }

    private final class FakeSolanaIndexerTransport: UniversalWalletHTTPTransport {
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

    private static let wallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let mint = "So11111111111111111111111111111111111111112"
    private static let signature = String(repeating: "1", count: 88)

    private static let serviceInfoJSON = Data("""
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

    private static let misroutedServiceInfoJSON = Data("""
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

    private static let misroutedServiceInfo = SolanaIndexerServiceInfo(
        schemaVersion: 1,
        serviceId: "ti.soramitsu.io",
        serviceName: "TON Indexer",
        ecosystem: "ton",
        chainId: "ton:mainnet",
        network: "mainnet",
        publicBaseUrl: "https://ti.soramitsu.io",
        readOnly: true,
        capabilities: ["account-transactions"],
        endpoints: ["transactions": "/api/indexer/v1/accounts/{addr}/txs"]
    )

    private static let balancesJSON = Data("""
    {
      "wallet": "\(wallet)",
      "native": {
        "type": "native",
        "mint": "SOL",
        "lamports": "0",
        "decimals": 9,
        "uiAmountString": "0"
      },
      "tokens": [],
      "total": 1,
      "syncedAt": 1
    }
    """.utf8)

    private static let transactionsJSON = Data("""
    {
      "wallet": "\(wallet)",
      "before": null,
      "nextBefore": null,
      "limit": 25,
      "total": 0,
      "syncedAt": 1,
      "transactions": []
    }
    """.utf8)

    private static let metadataJSON = Data("""
    {
      "mint": "\(mint)",
      "exists": true,
      "program": "spl-token",
      "extensions": ["transferFeeConfig", "transferHook"],
      "transferFeeConfig": {
        "transferFeeConfigAuthority": null,
        "withdrawWithheldAuthority": null,
        "withheldAmount": "0",
        "olderTransferFee": null,
        "newerTransferFee": null
      },
      "transferHook": {
        "authority": null,
        "programId": "\(wallet)",
        "extraAccountMetasAddress": "\(wallet)"
      },
      "syncedAt": 1
    }
    """.utf8)

    private static let metadataBatchJSON = Data("""
    {
      "total": 1,
      "syncedAt": 1,
      "tokens": []
    }
    """.utf8)
}
