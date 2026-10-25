import XCTest

@testable import SSFXCM

final class RemoteAssetMultilocationTests: XCTestCase {
    func testRemoteAssetMultilocationInit() {
        // arrange
        let name = "test"
        let chainId = "id"
        let assets: [AssetMultilocation] = [AssetMultilocation(
            id: "assetId",
            symbol: "assetSymbol",
            interiors: [.onlyChild]
        )]

        // act
        let remote = RemoteAssetMultilocation(
            name: name,
            chainId: chainId,
            assets: assets
        )
        // assert
        XCTAssertEqual(remote.name, name)
        XCTAssertEqual(remote.chainId, chainId)
        XCTAssertEqual(remote.assets.count, 1)
    }

    func testAssetMultilocationInit() {
        // arrange
        let id = "assetId"
        let symbol = "assetSymbol"
        let interiors: [XcmJunction] = [.onlyChild]

        // act
        let multiplication = AssetMultilocation(
            id: id,
            symbol: symbol,
            interiors: interiors
        )
        // assert
        XCTAssertEqual(multiplication.id, id)
        XCTAssertEqual(multiplication.symbol, symbol)
        XCTAssertEqual(multiplication.interiors.count, 1)
    }

    func testParentsDefaultToNilAndAreKeptWhenTheConfigStatesThem() {
        let derived = AssetMultilocation(id: "a", symbol: "A", interiors: [])
        let stated = AssetMultilocation(id: "b", symbol: "B", parents: 0, interiors: [])

        XCTAssertNil(derived.parents)
        XCTAssertEqual(stated.parents, 0)
        XCTAssertNotEqual(derived, stated)
    }

    func testDecodingKeepsTheParentsOfTheAstrEntryAndLeavesTheOthersToTheFactory() throws {
        // arrange: the shape of xcm/v2/xcm_token_locations.json
        let json = Data("""
        [{
          "name": "Polkadot",
          "chainId": "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
          "assets": [
            {"id": "dot", "symbol": "DOT", "versions": ["v1", "v3"], "interiors": []},
            {"id": "astr", "symbol": "ASTR", "parents": 0, "interiors": []},
            {"id": "usdt", "symbol": "USDt", "versions": ["v1", "v3"], "interiors": [
              {"parachain": 1000}, {"palletInstance": 50}, {"generalIndex": 1984}
            ]}
          ]
        }]
        """.utf8)

        // act
        let remote = try JSONDecoder().decode([RemoteAssetMultilocation].self, from: json)

        // assert
        let assets = try XCTUnwrap(remote.first?.assets)
        XCTAssertEqual(assets.map(\.parents), [nil, 0, nil])
        XCTAssertEqual(assets[2].interiors.count, 3)
        XCTAssertEqual(assets[1].interiors, [])
    }
}
