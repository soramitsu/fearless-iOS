import BigInt
import XCTest

@testable import SSFXCM

final class XcmV1MultiassetAssetIdTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let assetId = XcmV1MultiassetAssetId.concrete(.init(
            parents: 0,
            interior: .init(items: [.onlyChild])
        ))

        // act
        let encodedData = try JSONEncoder().encode(assetId)

        // assert
        XCTAssertEqual(encodedData.count, TestData.networkIdData?.count)
    }
}

extension XcmV1MultiassetAssetIdTests {
    enum TestData {
        static let networkIdData = """
        ["Concrete",{"interior":["X1",["OnlyChild",null]],"parents":"0"}]
        """.data(using: .utf8)
    }
}
