import XCTest
@testable import fearless

final class SolanaIndexerContractTests: XCTestCase {
    func testBuildsSIWalletEndpointURLsWithValidatedParameters() throws {
        XCTAssertEqual(
            try SolanaIndexerRoutes.serviceInfoURL().absoluteString,
            "\(UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString)/api/indexer/v1/service-info"
        )
        XCTAssertEqual(
            try SolanaIndexerRoutes.balancesURL(wallet: Self.wallet).absoluteString,
            "\(UniversalWalletRegistry.solanaIndexerBaseURL.absoluteString)/api/indexer/v1/accounts/\(Self.wallet)/balances"
        )
        XCTAssertEqual(
            try SolanaIndexerRoutes.assetsURL(wallet: Self.wallet, baseURL: "https://si.soramitsu.io/").absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/accounts/\(Self.wallet)/assets"
        )
        XCTAssertEqual(
            try SolanaIndexerRoutes.stateURL(wallet: Self.wallet, baseURL: "https://si.soramitsu.io/").absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/accounts/\(Self.wallet)/state"
        )
        XCTAssertEqual(
            try SolanaIndexerRoutes.transactionsURL(
                wallet: Self.wallet,
                baseURL: "https://si.soramitsu.io/",
                before: Self.signature,
                limit: 25
            ).absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/accounts/\(Self.wallet)/txs?limit=25&before=\(Self.signature)"
        )
        XCTAssertEqual(
            try SolanaIndexerRoutes.tokenMetadataURL(mint: Self.mint, baseURL: "https://si.soramitsu.io/").absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/tokens/\(Self.mint)/metadata"
        )
        XCTAssertEqual(
            try SolanaIndexerRoutes.tokenMetadataBatchURL(baseURL: "https://si.soramitsu.io/").absoluteString,
            "https://si.soramitsu.io/api/indexer/v1/tokens/metadata"
        )
        XCTAssertEqual(try SolanaIndexerRoutes.tokenMetadataBatchRequest(mints: [Self.mint]).mints, [Self.mint])
    }

    func testAllowsLocalHTTPBaseURLsButRejectsNonlocalInsecureBaseURLs() throws {
        XCTAssertEqual(try SolanaIndexerRoutes.normalizeBaseURL("http://localhost:3000/"), "http://localhost:3000")
        XCTAssertEqual(try SolanaIndexerRoutes.normalizeBaseURL("http://127.0.0.1:3000/"), "http://127.0.0.1:3000")

        assertRouteError(.invalidBaseURL) {
            try SolanaIndexerRoutes.normalizeBaseURL("http://si.soramitsu.io")
        }
        assertRouteError(.invalidBaseURL) {
            try SolanaIndexerRoutes.normalizeBaseURL("not a url")
        }
    }

    func testRejectsMalformedWalletTxAndTokenMetadataInputs() {
        assertRouteError(.invalidWallet) {
            _ = try SolanaIndexerRoutes.balancesURL(wallet: "../bad")
        }
        assertRouteError(.invalidMint) {
            _ = try SolanaIndexerRoutes.tokenMetadataURL(mint: "../bad")
        }
        assertRouteError(.invalidLimit) {
            _ = try SolanaIndexerRoutes.transactionsURL(wallet: Self.wallet, limit: 0)
        }
        assertRouteError(.invalidLimit) {
            _ = try SolanaIndexerRoutes.transactionsURL(wallet: Self.wallet, limit: 251)
        }
        assertRouteError(.invalidBefore) {
            _ = try SolanaIndexerRoutes.transactionsURL(wallet: Self.wallet, before: "../../../bad")
        }
        assertRouteError(.invalidMints) {
            _ = try SolanaIndexerRoutes.tokenMetadataBatchRequest(mints: [])
        }
        assertRouteError(.invalidMints) {
            _ = try SolanaIndexerRoutes.tokenMetadataBatchRequest(mints: Array(repeating: Self.mint, count: 101))
        }
    }

    func testParsesSIBalancesWithoutLosingLargeIntegerPrecision() throws {
        let data = """
        {
          "wallet": "\(Self.wallet)",
          "native": {
            "type": "native",
            "mint": "SOL",
            "lamports": "1234567890",
            "decimals": 9,
            "uiAmountString": "1.234567890"
          },
          "tokens": [
            {
              "type": "token",
              "accountAddress": "\(Self.tokenAccount)",
              "mint": "\(Self.mint)",
              "owner": "\(Self.wallet)",
              "program": "spl-token",
              "programId": "\(Self.tokenProgram)",
              "amount": "18446744073709551616",
              "decimals": 6,
              "uiAmountString": "18446744073709.551616",
              "state": "initialized",
              "isNative": false,
              "delegatedAmount": null,
              "rentExemptReserve": null
            }
          ],
          "total": 2,
          "syncedAt": 1710000000000
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SolanaWalletBalancesResponse.self, from: data)

        XCTAssertEqual(response.wallet, Self.wallet)
        XCTAssertEqual(response.native.lamports, "1234567890")
        XCTAssertEqual(response.tokens.first?.amount, "18446744073709551616")
        XCTAssertEqual(response.tokens.first?.program, "spl-token")
        XCTAssertEqual(response.total, 2)
    }

    func testVerifiesSIServiceIdentityAndRejectsMisroutedServiceInfo() throws {
        let data = """
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
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SolanaIndexerServiceInfo.self, from: data)

        XCTAssertTrue(response.isExpectedSIServiceInfo)
        XCTAssertFalse(
            SolanaIndexerServiceInfo(
                schemaVersion: response.schemaVersion,
                serviceId: "ti.soramitsu.io",
                serviceName: response.serviceName,
                ecosystem: response.ecosystem,
                chainId: response.chainId,
                network: response.network,
                publicBaseUrl: response.publicBaseUrl,
                readOnly: response.readOnly,
                capabilities: response.capabilities,
                endpoints: response.endpoints
            ).isExpectedSIServiceInfo
        )
    }

    private func assertRouteError(
        _ expected: SolanaIndexerRouteError,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) {
        XCTAssertThrowsError(try block(), file: file, line: line) { error in
            XCTAssertEqual(error as? SolanaIndexerRouteError, expected, file: file, line: line)
        }
    }

    private static let wallet = "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
    private static let mint = "So11111111111111111111111111111111111111112"
    private static let tokenAccount = "9xQeWvG816bUx9EPfQ4vF5xXw4wa9VFeTuzA7h4sFnH"
    private static let tokenProgram = "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
    private static let signature = String(repeating: "1", count: 88)
}
