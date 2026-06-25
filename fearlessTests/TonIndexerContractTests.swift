import XCTest
@testable import fearless

final class TonIndexerContractTests: XCTestCase {
    func testBuildsTiEndpointURLsWithValidatedParameters() throws {
        XCTAssertEqual(
            try TonIndexerRoutes.healthURL().absoluteString,
            "\(UniversalWalletRegistry.tonIndexerBaseURL.absoluteString)/api/indexer/v1/health"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.contractsURL(baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/contracts"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.serviceInfoURL(baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/service-info"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.balanceURL(address: Self.address, baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/balance"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.balancesURL(address: Self.address, baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/balances"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.assetsURL(address: Self.address, baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/assets"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.stateURL(address: Self.address, baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/state"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.transactionsURL(
                address: Self.address,
                baseURL: "https://ti.soramitsu.io/",
                page: 2,
                cursorLt: "10",
                cursorHash: Self.hash
            ).absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/txs?page=2&cursor_lt=10&cursor_hash=\(Self.encodedHash)"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.swapsURL(
                address: Self.address,
                baseURL: "https://ti.soramitsu.io/",
                limit: 25,
                fromUtime: 100,
                toUtime: 200,
                payToken: "TON",
                receiveToken: "TST",
                executionType: .market,
                status: .success,
                includeReverse: true
            ).absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/accounts/\(Self.address)/swaps?limit=25&from_utime=100&to_utime=200&pay_token=TON&receive_token=TST&execution_type=market&status=success&include_reverse=true"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.jettonTransferPayloadURL(
                jetton: Self.address,
                owner: Self.rawAddress.uppercased(),
                baseURL: "https://ti.soramitsu.io/"
            ).absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/jettons/\(Self.address)/transfer/\(Self.rawAddress)/payload"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.runGetMethodURL(baseURL: "https://ti.soramitsu.io/").absoluteString,
            "https://ti.soramitsu.io/api/indexer/v1/runGetMethod"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.runGetMethodRequest(address: Self.address, method: " seqno ").method,
            "seqno"
        )
        XCTAssertEqual(
            try TonIndexerRoutes.runGetMethodsRequest(calls: [
                try TonIndexerRoutes.runGetMethodRequest(address: Self.address, method: "seqno")
            ]).calls.count,
            1
        )
    }

    func testAllowsLocalHTTPBaseURLsButRejectsNonlocalInsecureBaseURLs() throws {
        XCTAssertEqual(try TonIndexerRoutes.normalizeBaseURL("http://localhost:3000/"), "http://localhost:3000")
        XCTAssertEqual(try TonIndexerRoutes.normalizeBaseURL("http://127.0.0.1:3000/"), "http://127.0.0.1:3000")

        XCTAssertThrowsError(try TonIndexerRoutes.normalizeBaseURL("http://ti.soramitsu.io")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidBaseURL)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.normalizeBaseURL("not a url")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidBaseURL)
        }
    }

    func testRejectsMalformedTONRouteInputsBeforeNetworkCalls() throws {
        XCTAssertThrowsError(try TonIndexerRoutes.balanceURL(address: "../bad")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidAddress)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.transactionsURL(address: Self.address, page: 0)) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidPage)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.transactionsURL(address: Self.address, cursorLt: "1")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .cursorMismatch)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.transactionsURL(address: Self.address, cursorLt: "bad", cursorHash: Self.hash)) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidCursor)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.transactionsURL(address: Self.address, cursorLt: "1", cursorHash: "../../../bad")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidCursor)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.swapsURL(address: Self.address, limit: 0)) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidLimit)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.swapsURL(address: Self.address, limit: 501)) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidLimit)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.swapsURL(address: Self.address, fromUtime: 20, toUtime: 10)) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidUtimeRange)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.swapsURL(address: Self.address, payToken: "../bad")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidTokenFilter)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.runGetMethodRequest(address: Self.address, method: "bad-method")) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidMethod)
        }
        XCTAssertThrowsError(try TonIndexerRoutes.runGetMethodsRequest(calls: [])) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidCalls)
        }
        let call = try TonIndexerRoutes.runGetMethodRequest(address: Self.address, method: "seqno")
        XCTAssertThrowsError(try TonIndexerRoutes.runGetMethodsRequest(calls: Array(repeating: call, count: 65))) { error in
            XCTAssertEqual(error as? TonIndexerRouteError, .invalidCalls)
        }
    }

    func testParsesTiBalanceWithoutLosingLargeIntegerPrecision() throws {
        let json = """
        {
          "ton": {
            "balance": "340282366920938463463374607431768211455",
            "last_tx_lt": "12345678901234567890",
            "last_tx_hash": "\(Self.hash)"
          },
          "jettons": [
            {
              "master": "\(Self.address)",
              "wallet": "\(Self.rawAddress)",
              "balance": "18446744073709551616",
              "decimals": 9,
              "symbol": "TST"
            }
          ],
          "confirmed": true,
          "updated_at": 1710000000000,
          "network": "mainnet"
        }
        """
        let response = try JSONDecoder().decode(TonBalanceResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.ton.balance, "340282366920938463463374607431768211455")
        XCTAssertEqual(response.ton.lastTxLt, "12345678901234567890")
        XCTAssertEqual(response.jettons.first?.balance, "18446744073709551616")
        XCTAssertEqual(response.network, "mainnet")
    }

    func testVerifiesTIServiceIdentityAndRejectsMisroutedServiceInfo() throws {
        let json = """
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
        """
        let response = try JSONDecoder().decode(TonIndexerServiceInfo.self, from: Data(json.utf8))

        XCTAssertTrue(response.isExpectedTIServiceInfo)
        XCTAssertFalse(
            TonIndexerServiceInfo(
                schemaVersion: response.schemaVersion,
                serviceId: "si.soramitsu.io",
                serviceName: response.serviceName,
                ecosystem: response.ecosystem,
                chainId: response.chainId,
                network: response.network,
                publicBaseUrl: response.publicBaseUrl,
                readOnly: response.readOnly,
                capabilities: response.capabilities,
                endpoints: response.endpoints
            ).isExpectedTIServiceInfo
        )
    }

    private static let address = "UQDxAUFadQXDd3EXGa3TLF_EF66gMc9h3_aZ0j0zXNoIYUCc"
    private static let rawAddress = "0:f101415a7505c377711719add32c5fc417aea031cf61dff699d23d335cda0861"
    private static let hash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    private static let encodedHash = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA%3D"
}
