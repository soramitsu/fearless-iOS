import TonAPI
import XCTest
@testable import fearless

final class TonNFTPreviewRegressionTests: XCTestCase {
    func testAbsentAndShortPreviewArraysDoNotTrap() throws {
        XCTAssertNil(try nft(previews: nil).imageURL)
        XCTAssertNil(try nft(previews: []).imageURL)
        XCTAssertEqual(try nft(previews: [preview("100x100")]).imageURL?.lastPathComponent, "100x100")
        XCTAssertEqual(
            try nft(previews: [preview("100x100"), preview("500x500")]).imageURL?.lastPathComponent,
            "500x500"
        )
    }

    func testResolutionPreferenceAndUnknownFallbackPreserveAvailableImage() throws {
        XCTAssertEqual(
            try nft(previews: [preview("5x5"), preview("1500x1500"), preview("500x500")]).imageURL?.lastPathComponent,
            "500x500"
        )
        XCTAssertEqual(try nft(previews: [preview("custom")]).imageURL?.lastPathComponent, "custom")
        XCTAssertEqual(
            try nft(previews: [], image: "https://example.invalid/original").imageURL?.lastPathComponent,
            "original"
        )
    }

    private func preview(_ resolution: String) -> [String: String] {
        ["resolution": resolution, "url": "https://example.invalid/" + resolution]
    }

    private func nft(previews: [[String: String]]?, image: String? = nil) throws -> TonNFT {
        var json: [String: Any] = [
            "address": "0:" + String(repeating: "11", count: 32), "index": 0,
            "verified": false, "metadata": image.map { ["image": $0] } ?? [:], "approved_by": []
        ]
        if let previews {
            json["previews"] = previews
        }
        let item = try JSONDecoder()
            .decode(Components.Schemas.NftItem.self, from: JSONSerialization.data(withJSONObject: json))
        return try TonNFT(nftItem: item)
    }
}
