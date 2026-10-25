import BigInt
import XCTest

@testable import SSFXCM

final class XcmV1MultiAssetTests: XCTestCase {
    func testXcmV1MultiAssetLocationInit() {
        // arrange
        let multiLocation = XcmV1MultiLocation(parents: 0, interior: .init(items: [.onlyChild]))
        let amount = BigUInt()

        // act
        let asset = XcmV1MultiAsset(multilocation: multiLocation, amount: amount)

        // assert
        XCTAssertEqual(asset.assetId, .concrete(multiLocation))
        XCTAssertEqual(asset.fun, .fungible(amount: amount))
    }

    func testXcmV1MultiAssetIdInit() {
        // arrange
        let assetId: XcmV1MultiassetAssetId = .abstract(Data())
        let fun: XcmV1MultiassetFungibility = .fungible(amount: BigUInt())

        // act
        let asset = XcmV1MultiAsset(assetId: assetId, fun: fun)

        // assert
        XCTAssertEqual(asset.assetId, assetId)
        XCTAssertEqual(asset.fun, fun)
    }
}
