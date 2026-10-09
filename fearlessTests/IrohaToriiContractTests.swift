import XCTest
@testable import fearless

final class IrohaToriiContractTests: XCTestCase {
    func testBuildsTairaToriiEndpointURLsWithValidatedParameters() throws {
        XCTAssertEqual(try IrohaToriiRoutes.healthURL().absoluteString, "https://taira.sora.org/health")
        XCTAssertEqual(try IrohaToriiRoutes.mcpURL().absoluteString, "https://taira.sora.org/v1/mcp")
        XCTAssertEqual(
            try IrohaToriiRoutes.accountsURL(limit: 50, offset: 10, countMode: .exact).absoluteString,
            "https://taira.sora.org/v1/accounts?limit=50&offset=10&count_mode=exact"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountURL(accountID: Self.account).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountAssetsURL(
                accountID: Self.account,
                limit: 25,
                countMode: .bounded,
                asset: Self.assetDefinitionId,
                scope: "global"
            ).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/assets?limit=25&count_mode=bounded&asset=\(Self.assetDefinitionId)&scope=global"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.assetDefinitionsURL(
                limit: IrohaToriiRoutes.maxLimit,
                offset: 0,
                countMode: .bounded
            ).absoluteString,
            "https://taira.sora.org/v1/assets/definitions?limit=500&offset=0&count_mode=bounded"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.transactionStatusURL(hash: Self.hash, scope: .global).absoluteString,
            "https://taira.sora.org/v1/pipeline/transactions/status?hash=\(Self.hash)&scope=global"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.mcpJSONRPCRequest(method: " tools/list ", id: "1").method,
            "tools/list"
        )
    }

    func testAllowsLocalHTTPBaseURLsButRejectsNonlocalInsecureBaseURLs() throws {
        XCTAssertEqual(try IrohaToriiRoutes.normalizeBaseURL("http://localhost:8080/"), "http://localhost:8080")
        XCTAssertEqual(try IrohaToriiRoutes.normalizeBaseURL("http://127.0.0.1:8080/"), "http://127.0.0.1:8080")

        XCTAssertThrowsError(try IrohaToriiRoutes.normalizeBaseURL("http://taira.sora.org")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidBaseURL)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.normalizeBaseURL("not a url")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidBaseURL)
        }
        for unsafeBaseURL in [
            "https://user:secret@taira.sora.org",
            "https://taira.sora.org?route=attacker",
            "https://taira.sora.org#route",
            "ftp://localhost:8080"
        ] {
            XCTAssertThrowsError(try IrohaToriiRoutes.normalizeBaseURL(unsafeBaseURL)) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidBaseURL)
            }
        }
        XCTAssertEqual(
            try IrohaToriiRoutes.requireToriiBaseURL(UniversalWalletRegistry.nexus),
            "https://minamoto.sora.org"
        )
    }

    func testRejectsMalformedIrohaRouteInputsBeforeNetworkCalls() throws {
        XCTAssertThrowsError(try IrohaToriiRoutes.accountURL(accountID: "../bad")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAccountID)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountAssetsURL(accountID: Self.account, asset: "../bad")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAsset)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountAssetsURL(accountID: Self.account, asset: "xor#universal")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAsset)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountAssetsURL(accountID: Self.account, scope: "bad/scope")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidScope)
        }
        for scope in ["rewards", "dataspace:01", "dataspace:18446744073709551616"] {
            XCTAssertThrowsError(
                try IrohaToriiRoutes.accountAssetsURL(accountID: Self.account, scope: scope)
            ) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidScope)
            }
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountsURL(limit: 0)) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidLimit)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountsURL(limit: 501)) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidLimit)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountsURL(offset: -1)) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidOffset)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.transactionStatusURL(hash: "not-a-hash")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidHash)
        }
        XCTAssertThrowsError(
            try IrohaToriiRoutes.transactionStatusURL(hash: String(repeating: "a", count: 64))
        ) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidHash)
        }
        for nonCanonicalHash in ["0x\(Self.hash)", Self.hash.uppercased(), " \(Self.hash)"] {
            XCTAssertThrowsError(try IrohaToriiRoutes.transactionStatusURL(hash: nonCanonicalHash)) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidHash)
            }
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.mcpJSONRPCRequest(method: "tools/list", id: "../bad")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidJSONRPCID)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.mcpJSONRPCRequest(method: "../bad", id: "1")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidMCPMethod)
        }
    }

    func testRejectsPaddedAssetDefinitionIdentifiersWithoutCanonicalizing() {
        for paddedAssetDefinitionId in [
            " \(Self.assetDefinitionId)",
            "\(Self.assetDefinitionId) ",
            "\n\(Self.assetDefinitionId)\t"
        ] {
            XCTAssertThrowsError(
                try IrohaToriiRoutes.normalizeAssetDefinitionId(paddedAssetDefinitionId)
            ) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAsset)
            }
        }
    }

    func testParsesAccountAssetQuantitiesAsStrings() throws {
        let json = """
        {
          "items": [
            {
              "account_id": "\(Self.account)",
              "asset": "\(Self.assetDefinitionId)",
              "quantity": "340282366920938463463374607431768211455",
              "scope": "global"
            }
          ],
          "has_more": false,
          "count_mode": "exact",
          "total": 1
        }
        """
        let response = try JSONDecoder().decode(IrohaAccountAssetListResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.items.first?.quantity, "340282366920938463463374607431768211455")
        XCTAssertEqual(response.countMode, "exact")
        XCTAssertEqual(response.total, 1)
    }

    func testParsesTransactionStatusAndMCPJSON() throws {
        let statusJSON = """
        {
          "hash": "\(Self.hash)",
          "status": {
            "kind": "Committed",
            "block_height": 42
          },
          "scope": "global",
          "resolved_from": "state"
        }
        """
        let status = try JSONDecoder().decode(IrohaPipelineTransactionStatusResponse.self, from: Data(statusJSON.utf8))
        XCTAssertEqual(status.status.kind, .committed)
        XCTAssertEqual(status.status.blockHeight, 42)

        let request = try IrohaToriiRoutes.mcpJSONRPCRequest(
            method: "tools/call",
            id: "req-1",
            params: ["name": .string("accounts_list")]
        )
        let encoded = try JSONEncoder().encode(request)
        let decoded = try JSONDecoder().decode(IrohaMcpJsonRPCRequest.self, from: encoded)

        XCTAssertEqual(decoded.jsonrpc, "2.0")
        XCTAssertEqual(decoded.params?["name"], .string("accounts_list"))
    }

    private static let account = "testuﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱﾇﾆｲMﾒSﾏﾑヱﾇJヱFmJﾇMs6YN687Y"
    private static let encodedAccount = "testu%EF%BE%9B1Pc%EF%BE%852%EF%BE%97t%EF%BE%89a%EF%BE%98L%EF%BE%95%EF%BD%BD2M%E3%83%B1%EF%BE%90%EF%BE%8E%EF%BD%B3%EF%BE%93%E3%83%B1%EF%BE%87%EF%BE%86%EF%BD%B2M%EF%BE%92S%EF%BE%8F%EF%BE%91%E3%83%B1%EF%BE%87J%E3%83%B1FmJ%EF%BE%87Ms6YN687Y"
    private static let hash = String(repeating: "a", count: 63) + "1"
    private static let assetDefinitionId = "6TEAJqbb8oEPmLncoNiMRbLEK6tw"
}
