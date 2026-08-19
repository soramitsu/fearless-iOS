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
                asset: "xor#sora",
                scope: "global"
            ).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/assets?limit=25&count_mode=bounded&asset=xor%23sora&scope=global"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountHistoryURL(
                accountID: Self.account,
                limit: 25,
                offset: 5,
                countMode: .bounded,
                assetID: "xor#universal"
            ).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/history?limit=25&offset=5&count_mode=bounded&asset_id=xor%23universal"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.assetDefinitionsURL().absoluteString,
            "https://taira.sora.org/v1/assets/definitions"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.assetDefinitionURL(selector: "xor#universal").absoluteString,
            "https://taira.sora.org/v1/assets/definitions/xor%23universal"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.assetAliasResolutionURL().absoluteString,
            "https://taira.sora.org/v1/assets/aliases/resolve"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.submitTransactionURL().absoluteString,
            "https://taira.sora.org/v1/pipeline/transactions"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.transactionStatusURL(hash: "0x\(Self.hash)", scope: .global).absoluteString,
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
        XCTAssertThrowsError(try IrohaToriiRoutes.accountHistoryURL(accountID: Self.account, assetID: "../bad")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAsset)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountAssetsURL(accountID: Self.account, scope: "bad/scope")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidScope)
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
        XCTAssertThrowsError(try IrohaToriiRoutes.mcpJSONRPCRequest(method: "tools/list", id: "../bad")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidJSONRPCID)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.mcpJSONRPCRequest(method: "../bad", id: "1")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidMCPMethod)
        }
    }

    func testParsesAccountAssetQuantitiesAsStrings() throws {
        let json = """
        {
          "items": [
            {
              "account_id": "\(Self.account)",
              "asset": "xor#sora",
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

    func testDecodesDeployedTairaLegacyPaginationWithoutInventingMetadata() throws {
        let accountAssetsJSON = """
        {
          "items": [
            {
              "account_id": "\(Self.account)",
              "asset": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "asset_alias": "xor#universal",
              "quantity": "10000",
              "scope": "global"
            }
          ],
          "total": 1
        }
        """
        let accountAssets = try JSONDecoder().decode(
            IrohaAccountAssetListResponse.self,
            from: Data(accountAssetsJSON.utf8)
        )
        XCTAssertEqual(accountAssets.items.count, 1)
        XCTAssertNil(accountAssets.hasMore)
        XCTAssertNil(accountAssets.countMode)
        XCTAssertEqual(accountAssets.total, 1)

        let definitionsJSON = """
        {
          "items": [
            {
              "id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "alias": "xor#universal",
              "spec": { "scale": null }
            }
          ],
          "total": 1
        }
        """
        let definitions = try JSONDecoder().decode(
            IrohaAssetDefinitionListResponse.self,
            from: Data(definitionsJSON.utf8)
        )
        XCTAssertEqual(definitions.items.first?.id, UniversalWalletRegistry.tairaNativeXorAssetDefinitionId)
        XCTAssertNil(definitions.hasMore)
        XCTAssertNil(definitions.countMode)
        XCTAssertEqual(definitions.total, 1)
    }

    func testDecodesDeployedTairaAccountHistoryProjection() throws {
        let json = """
        {
          "items": [
            {
              "id": "raw-1",
              "source": "block_store",
              "type": "RAW_ON_CHAIN",
              "status": "SUCCESS",
              "direction": "self",
              "account_id": "\(Self.account)"
            },
            {
              "id": "movement-1",
              "source": "block_store",
              "type": "TRANSFER",
              "timestamp_ms": 1704067200000,
              "status": "SUCCESS",
              "result_ok": true,
              "direction": "outgoing",
              "account_id": "\(Self.account)",
              "counterparty_account_id": "i105-peer",
              "asset_id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw#\(Self.account)",
              "asset_definition_id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "amount": "1.25",
              "tx_hash": "\(Self.hash)"
            }
          ],
          "has_more": false,
          "count_mode": "bounded"
        }
        """
        let response = try JSONDecoder().decode(
            IrohaAccountHistoryResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.items.count, 2)
        XCTAssertNil(response.total)
        XCTAssertEqual(response.items[0].type, "RAW_ON_CHAIN")
        XCTAssertNil(response.items[0].amount)
        XCTAssertEqual(response.items[1].assetDefinitionID, UniversalWalletRegistry.tairaNativeXorAssetDefinitionId)
        XCTAssertEqual(response.items[1].amount, "1.25")
    }

    func testParsesTransactionStatusAndMCPJSON() throws {
        let statusJSON = """
        {
          "hash": "\(Self.hash)",
          "status": {
            "kind": "committed",
            "block_height": 42
          },
          "scope": "global",
          "resolved_from": "pipeline"
        }
        """
        let status = try JSONDecoder().decode(IrohaPipelineTransactionStatusResponse.self, from: Data(statusJSON.utf8))
        XCTAssertEqual(status.status.kind, "committed")
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

    func testDecodesCanonicalAndDistinctTairaXORNumericSpecs() throws {
        let json = """
        {
          "items": [
            {
              "id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "name": "xor",
              "alias": "xor#universal",
              "spec": { "scale": null }
            },
            {
              "id": "61CtjvNd9T3THAR65GsMVHr82Bjc",
              "name": "xor",
              "alias": "xor#sora.universal",
              "spec": { "scale": 9 }
            }
          ],
          "has_more": false,
          "count_mode": "bounded",
          "total": 2
        }
        """
        let response = try JSONDecoder().decode(
            IrohaAssetDefinitionListResponse.self,
            from: Data(json.utf8)
        )

        let nativeXOR = try XCTUnwrap(response.items.first)
        XCTAssertNotNil(nativeXOR.spec)
        XCTAssertNil(nativeXOR.spec?.scale)
        XCTAssertEqual(nativeXOR.spec?.fixedPointAdapterPrecision, 28)

        let soraXOR = try XCTUnwrap(response.items.last)
        XCTAssertEqual(soraXOR.spec?.scale, 9)
        XCTAssertEqual(soraXOR.spec?.fixedPointAdapterPrecision, 9)
        XCTAssertNil(IrohaAssetDefinitionSpec(scale: 29).fixedPointAdapterPrecision)
    }

    func testDecodesPermanentTairaXORAliasResolution() throws {
        let json = """
        {
          "alias": "xor#universal",
          "asset_definition_id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
          "asset_name": "xor",
          "source": "world_state",
          "alias_binding": {
            "alias": "xor#universal",
            "status": "permanent",
            "bound_at_ms": 1786967275740
          }
        }
        """
        let resolution = try JSONDecoder().decode(
            IrohaAssetAliasResolution.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(resolution.alias, UniversalWalletRegistry.tairaNativeXorAlias)
        XCTAssertEqual(
            resolution.assetDefinitionID,
            UniversalWalletRegistry.tairaNativeXorAssetDefinitionId
        )
        XCTAssertEqual(resolution.aliasBinding?.status, "permanent")
    }

    private static let account = "testuﾛ1Pcﾅ2ﾗtﾉaﾘLﾕｽ2MヱﾐﾎｳﾓヱﾇﾆｲMﾒSﾏﾑヱﾇJヱFmJﾇMs6YN687Y"
    private static let encodedAccount = "testu%EF%BE%9B1Pc%EF%BE%852%EF%BE%97t%EF%BE%89a%EF%BE%98L%EF%BE%95%EF%BD%BD2M%E3%83%B1%EF%BE%90%EF%BE%8E%EF%BD%B3%EF%BE%93%E3%83%B1%EF%BE%87%EF%BE%86%EF%BD%B2M%EF%BE%92S%EF%BE%8F%EF%BE%91%E3%83%B1%EF%BE%87J%E3%83%B1FmJ%EF%BE%87Ms6YN687Y"
    private static let hash = String(repeating: "a", count: 64)
}
