import XCTest
@testable import fearless

final class IrohaToriiContractTests: XCTestCase {
    func testBuildsTairaToriiEndpointURLsWithValidatedParameters() throws {
        XCTAssertEqual(try IrohaToriiRoutes.healthURL().absoluteString, "https://taira.sora.org/health")
        XCTAssertEqual(
            try IrohaToriiRoutes.accountsURL(limit: 50, cursor: Self.cursor).absoluteString,
            "https://taira.sora.org/v1/accounts?limit=50&cursor=\(Self.cursor)"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountURL(accountID: Self.account).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountAssetsURL(accountID: Self.account, limit: 25).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/assets?limit=25"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountAssetsURL(
                accountID: Self.account,
                limit: 500,
                cursor: Self.cursor
            ).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/assets?limit=500&cursor=\(Self.cursor)"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.accountHistoryURL(
                accountID: Self.account,
                limit: 25,
                cursor: Self.cursor,
                filter: IrohaToriiRoutes.transferHistoryFilter(
                    assetDefinitionIDs: [UniversalWalletRegistry.tairaNativeXorAssetDefinitionId]
                )
            ).absoluteString,
            "https://taira.sora.org/v1/accounts/\(Self.encodedAccount)/history?limit=25&cursor=\(Self.cursor)" +
                "&filter=asset_definition_id%20in%20%5B%226TEAJqbb8oEPmLncoNiMRbLEK6tw%22%5D%20and%20type%20%3D%20%22TRANSFER%22"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.assetDefinitionsURL().absoluteString,
            "https://taira.sora.org/v1/assets/definitions"
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.assetDefinitionsURL(limit: 500, cursor: Self.cursor).absoluteString,
            "https://taira.sora.org/v1/assets/definitions?limit=500&cursor=\(Self.cursor)"
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
        XCTAssertThrowsError(try IrohaToriiRoutes.transferHistoryFilter(assetDefinitionIDs: ["../bad"])) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAsset)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.transferHistoryFilter(assetDefinitionIDs: [])) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidAsset)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountsURL(limit: 0)) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidLimit)
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.accountsURL(limit: 501)) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidLimit)
        }
        for cursor in ["", "AQ8 bad", "AQ8&offset=0", "AQ8=", String(repeating: "A", count: 4097)] {
            XCTAssertThrowsError(try IrohaToriiRoutes.accountsURL(cursor: cursor)) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidCursor)
            }
            XCTAssertThrowsError(try IrohaToriiRoutes.accountHistoryURL(accountID: Self.account, cursor: cursor)) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidCursor)
            }
        }
        for filter in ["", "   ", "type = \"TRANSFER\"\n", String(repeating: "a", count: 2049)] {
            XCTAssertThrowsError(try IrohaToriiRoutes.accountHistoryURL(accountID: Self.account, filter: filter)) { error in
                XCTAssertEqual(error as? IrohaToriiRouteError, .invalidFilter)
            }
        }
        XCTAssertThrowsError(try IrohaToriiRoutes.transactionStatusURL(hash: "not-a-hash")) { error in
            XCTAssertEqual(error as? IrohaToriiRouteError, .invalidHash)
        }
    }

    func testTransferHistoryFilterQuotesEachAssetDefinitionOnce() throws {
        XCTAssertEqual(
            try IrohaToriiRoutes.transferHistoryFilter(
                assetDefinitionIDs: [
                    UniversalWalletRegistry.tairaNativeXorAssetDefinitionId,
                    " \(UniversalWalletRegistry.tairaNativeXorAssetDefinitionId) ",
                    "61CtjvNd9T3THAR65GsMVHr82Bjc"
                ]
            ),
            #"asset_definition_id in ["6TEAJqbb8oEPmLncoNiMRbLEK6tw", "61CtjvNd9T3THAR65GsMVHr82Bjc"] and type = "TRANSFER""#
        )
        XCTAssertEqual(
            try IrohaToriiRoutes.transferHistoryFilter(assetDefinitionIDs: [#"a"b\c"#]),
            #"asset_definition_id in ["a\"b\\c"] and type = "TRANSFER""#
        )
    }

    func testEncodesFilterLiteralsExactlyIncludingPlusSigns() throws {
        let url = try IrohaToriiRoutes.accountHistoryURL(
            accountID: Self.account,
            filter: #"asset_definition_id in ["a+b&c=d#e"] and type = "TRANSFER""#
        )
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery)

        XCTAssertEqual(
            query,
            "filter=asset_definition_id%20in%20%5B%22a%2Bb%26c%3Dd%23e%22%5D%20and%20type%20%3D%20%22TRANSFER%22"
        )
        XCTAssertFalse(query.contains("+"))
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
          "next_cursor": "\(Self.cursor)"
        }
        """
        let response = try JSONDecoder().decode(IrohaAccountAssetListResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.items.first?.quantity, "340282366920938463463374607431768211455")
        XCTAssertEqual(response.nextCursor, Self.cursor)
        XCTAssertNil(response.total)
    }

    func testDecodesDeployedTairaCursorPagination() throws {
        let accountAssetsJSON = """
        {
          "items": [
            {
              "account_id": "\(Self.account)",
              "asset": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "asset_alias": "xor#universal",
              "asset_name": "XOR",
              "quantity": "10000",
              "scope": "global"
            }
          ],
          "next_cursor": null
        }
        """
        let accountAssets = try JSONDecoder().decode(
            IrohaAccountAssetListResponse.self,
            from: Data(accountAssetsJSON.utf8)
        )
        XCTAssertEqual(accountAssets.items.count, 1)
        XCTAssertNil(accountAssets.nextCursor)

        let definitionsJSON = """
        {
          "items": [
            {
              "id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "alias": "xor#universal",
              "spec": { "scale": null }
            }
          ],
          "next_cursor": "\(Self.cursor)"
        }
        """
        let definitions = try JSONDecoder().decode(
            IrohaAssetDefinitionListResponse.self,
            from: Data(definitionsJSON.utf8)
        )
        XCTAssertEqual(definitions.items.first?.id, UniversalWalletRegistry.tairaNativeXorAssetDefinitionId)
        XCTAssertEqual(definitions.nextCursor, Self.cursor)

        let accountsJSON = """
        {
          "items": [{ "id": "\(Self.account)" }],
          "next_cursor": "\(Self.cursor)"
        }
        """
        let accounts = try JSONDecoder().decode(IrohaAccountListResponse.self, from: Data(accountsJSON.utf8))
        XCTAssertEqual(accounts.items.map(\.id), [Self.account])
        XCTAssertEqual(accounts.nextCursor, Self.cursor)
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
              "id": "\(Self.hash):\(Self.account):1",
              "source": "transaction",
              "type": "TRANSFER",
              "timestamp_ms": 1793156101069,
              "status": "SUCCESS",
              "result_ok": true,
              "direction": "outgoing",
              "account_id": "\(Self.account)",
              "counterparty_account_id": "i105-peer",
              "asset_id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw#\(Self.account)",
              "asset_definition_id": "6TEAJqbb8oEPmLncoNiMRbLEK6tw",
              "amount": "25000",
              "tx_hash": "\(Self.hash)",
              "block_height": 5507,
              "block_index": 0,
              "movement_index": 1
            }
          ],
          "next_cursor": "\(Self.cursor)"
        }
        """
        let response = try JSONDecoder().decode(
            IrohaAccountHistoryResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(response.items.count, 2)
        XCTAssertEqual(response.nextCursor, Self.cursor)
        XCTAssertEqual(response.items[0].type, "RAW_ON_CHAIN")
        XCTAssertNil(response.items[0].amount)
        XCTAssertEqual(response.items[1].assetDefinitionID, UniversalWalletRegistry.tairaNativeXorAssetDefinitionId)
        XCTAssertEqual(response.items[1].amount, "25000")
        XCTAssertEqual(response.items[1].transactionHash, Self.hash)
    }

    func testParsesTransactionStatus() throws {
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
    /// Shape of a live Taira history cursor (base64url, no padding).
    private static let cursor = "AQ85p7D_UiA0KVpysGJxmhOHWzUwMTUsbnVsbCxudWxsXQ"
}
