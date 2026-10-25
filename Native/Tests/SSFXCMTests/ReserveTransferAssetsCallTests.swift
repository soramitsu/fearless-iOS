import XCTest

@testable import SSFXCM

final class ReserveTransferAssetsCallTests: XCTestCase {
    func testReserveTransferAssetsCallTestsInit() {
        // arrange
        let location = XcmV1MultiLocation(
            parents: 0,
            interior: XcmV1MultilocationJunctions(items: [.onlyChild])
        )
        let destination: XcmVersionedMultiLocation = .V4(location)
        let beneficiary: XcmVersionedMultiLocation = .V3(location)
        let assets: XcmVersionedMultiAssets = .V5([XcmV1MultiAsset(
            multilocation: location,
            amount: 0
        )])
        let weightLimit: XcmWeightLimit = .unlimited
        let feeAssetItem: UInt32 = 0

        // act
        let assetsCall = ReserveTransferAssetsCall(
            destination: destination,
            beneficiary: beneficiary,
            assets: assets,
            weightLimit: weightLimit,
            feeAssetItem: feeAssetItem
        )

        XCTAssertEqual(assetsCall.destination, destination)
        XCTAssertEqual(assetsCall.beneficiary, beneficiary)
        XCTAssertEqual(assetsCall.assets, assets)
        XCTAssertEqual(assetsCall.weightLimit, weightLimit)
        XCTAssertEqual(assetsCall.feeAssetItem, feeAssetItem)
    }
}
