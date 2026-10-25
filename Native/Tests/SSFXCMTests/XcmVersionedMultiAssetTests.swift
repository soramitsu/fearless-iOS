import BigInt
import XCTest

@testable import SSFXCM

final class XcmVersionedMultiAssetTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let asset = XcmVersionedMultiAsset.V3(.init(
            assetId: .abstract(Data()),
            fun: .fungible(amount: BigUInt())
        ))

        // act
        let encodedData = try JSONEncoder().encode(asset)

        // assert
        XCTAssertEqual(encodedData.count, TestData.assetData?.count)
    }

    func testV4AndV5AssetsHoldTheLocationWithoutConcrete() throws {
        let asset = XcmV1MultiAsset(
            multilocation: .init(parents: 1, interior: .init(items: [.parachain(1000)])),
            amount: BigUInt(5)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        for (versioned, name) in [(XcmVersionedMultiAsset.V4(asset), "V4"), (.V5(asset), "V5")] {
            let json = try String(decoding: encoder.encode(versioned), as: UTF8.self)
            XCTAssertEqual(
                json,
                #"[""# + name +
                    #"",{"fun":["Fungible","5"],"id":{"interior":["X1",[["Parachain","1000"]]],"parents":"1"}}]"#
            )
        }
    }

    func testV4HasNoAbstractAssets() {
        let asset = XcmVersionedMultiAsset.V4(.init(
            assetId: .abstract(Data([1])),
            fun: .fungible(amount: BigUInt())
        ))

        XCTAssertThrowsError(try JSONEncoder().encode(asset))
    }
}

extension XcmVersionedMultiAssetTests {
    enum TestData {
        static let assetData = """
        ["V3",{"fun":["Fungible","0"],"id":["Abstract",[]]}]
        """.data(using: .utf8)
    }
}
