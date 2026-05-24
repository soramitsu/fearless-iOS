import XCTest
@testable import fearless

final class ChainSyncServiceCompatibilityTests: XCTestCase {
    func testCoerceChainsPayloadForCompatibilityNormalizesBlockscoutTypes() throws {
        let payload: [[String: Any]] = [[
            "externalApi": [
                "history": [
                    "type": "klaytn",
                    "url": "https://blockscout.example/api"
                ],
                "staking": [
                    "type": "blockscout",
                    "url": "https://blockscout.example/staking"
                ],
                "explorers": [
                    [
                        "type": "blockscout",
                        "url": "https://blockscout.example/explorer"
                    ],
                    [
                        "type": "etherscan",
                        "url": "https://etherscan.io"
                    ]
                ]
            ]
        ]]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let coerced = try ChainSyncService.coerceChainsPayloadForCompatibility(data)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: coerced, options: []) as? [[String: Any]])

        let externalApi = try XCTUnwrap(json.first?["externalApi"] as? [String: Any])
        let history = try XCTUnwrap(externalApi["history"] as? [String: Any])
        let staking = try XCTUnwrap(externalApi["staking"] as? [String: Any])
        let explorers = try XCTUnwrap(externalApi["explorers"] as? [[String: Any]])

        XCTAssertEqual(history["type"] as? String, ChainSyncService.historyExplorerCompatibilityType)
        XCTAssertEqual(staking["type"] as? String, ChainSyncService.stakingExplorerCompatibilityType)
        XCTAssertEqual(explorers.first?["type"] as? String, ChainSyncService.genericExplorerCompatibilityType)
        XCTAssertEqual(explorers.last?["type"] as? String, "etherscan")
    }

    func testCoerceChainsPayloadForCompatibilityUsesPiIndexerForSoraMainnetData() throws {
        let oldHistoryUrl = "https://squid.subsquid.io/sora/v/v5/graphql"
        let oldPricingUrl = "https://api.subquery.network/sq/sora-xor/sora-prod"

        let payload: [[String: Any]] = [[
            "chainId": ChainSyncService.soraMainnetChainId,
            "externalApi": [
                "history": [
                    "type": "sora",
                    "url": oldHistoryUrl
                ],
                "staking": [
                    "type": "sora",
                    "url": oldHistoryUrl
                ],
                "pricing": [
                    "type": "sora",
                    "url": oldPricingUrl
                ]
            ]
        ]]

        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let coerced = try ChainSyncService.coerceChainsPayloadForCompatibility(data)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: coerced, options: []) as? [[String: Any]])

        let externalApi = try XCTUnwrap(json.first?["externalApi"] as? [String: Any])
        let history = try XCTUnwrap(externalApi["history"] as? [String: Any])
        let staking = try XCTUnwrap(externalApi["staking"] as? [String: Any])
        let pricing = try XCTUnwrap(externalApi["pricing"] as? [String: Any])
        let explorers = try XCTUnwrap(externalApi["explorers"] as? [[String: Any]])

        XCTAssertEqual(history["type"] as? String, "sora")
        XCTAssertEqual(history["url"] as? String, ChainSyncService.soraPiIndexerUrl)
        XCTAssertEqual(pricing["type"] as? String, "sora")
        XCTAssertEqual(pricing["url"] as? String, ChainSyncService.soraPiIndexerUrl)
        XCTAssertEqual(staking["url"] as? String, oldHistoryUrl)
        XCTAssertEqual(explorers.count, 2)
        XCTAssertEqual(explorers.first?["type"] as? String, "subscan")
        XCTAssertEqual(explorers.first?["types"] as? [String], ["extrinsic"])
        XCTAssertEqual(explorers.first?["url"] as? String, ChainSyncService.soraMetricsExtrinsicUrl)
        XCTAssertEqual(explorers.last?["type"] as? String, "subscan")
        XCTAssertEqual(explorers.last?["types"] as? [String], ["account", "address"])
        XCTAssertEqual(explorers.last?["url"] as? String, ChainSyncService.soraMetricsAccountUrl)
    }

    func testSoraSubqueryPricePageDecodesPiEdgesShape() throws {
        let payload = """
        {
          "entities": {
            "edges": [
              {
                "node": {
                  "id": "0x0200000000000000000000000000000000000000000000000000000000000000",
                  "priceUSD": "5.27404837",
                  "priceChangeDay": 0.2568997713952644
                }
              }
            ],
            "pageInfo": {
              "hasNextPage": false,
              "endCursor": "0"
            }
          }
        }
        """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let response = try JSONDecoder().decode(SoraSubqueryPriceResponse.self, from: data)

        XCTAssertEqual(response.entities.nodes.count, 1)
        XCTAssertEqual(response.entities.nodes.first?.priceUsd, "5.27404837")
        XCTAssertEqual(response.entities.pageInfo.hasNextPage, false)
    }

    func testSoraHistoryElementNormalizesPiMillisecondTimestamp() throws {
        let payload = """
        {
          "historyElementsConnection": {
            "edges": [
              {
                "node": {
                  "id": "history-1",
                  "timestamp": 1779398268000,
                  "execution": {
                    "success": true
                  }
                }
              }
            ],
            "pageInfo": {
              "hasNextPage": false,
              "endCursor": "0"
            },
            "totalCount": 1
          }
        }
        """

        let data = try XCTUnwrap(payload.data(using: .utf8))
        let response = try JSONDecoder().decode(SoraSubsquidHistoryConnectionResponse.self, from: data)
        let node = try XCTUnwrap(response.historyElementsConnection.edges.first?.node)

        XCTAssertEqual(node.itemTimestamp, 1_779_398_268)
        XCTAssertEqual(node.execution?.success, true)
    }
}
