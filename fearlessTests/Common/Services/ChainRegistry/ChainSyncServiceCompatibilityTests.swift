import XCTest
@testable import fearless

final class ChainSyncServiceCompatibilityTests: XCTestCase {
    func testCoerceChainsPayloadForCompatibilityNormalizesBlockscoutTypes() throws {
        let payload: [[String: Any]] = [[
            "externalApi": [
                "history": [
                    "type": "blockscout",
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

        XCTAssertEqual(history["type"] as? String, ChainSyncService.blockscoutCompatibilityType)
        XCTAssertEqual(staking["type"] as? String, ChainSyncService.blockscoutCompatibilityType)
        XCTAssertEqual(explorers.first?["type"] as? String, ChainSyncService.blockscoutCompatibilityType)
        XCTAssertEqual(explorers.last?["type"] as? String, "etherscan")
    }
}
