import BigInt
import XCTest

@testable import SSFXCM

final class XcmVersionedMultiAssetsTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let assets = XcmVersionedMultiAssets.V3([])

        // act
        let encodedData = try JSONEncoder().encode(assets)

        // assert
        XCTAssertEqual(encodedData, TestData.assetsData)
    }
}

extension XcmVersionedMultiAssetsTests {
    enum TestData {
        static let assetsData = """
        ["V3",[]]
        """.data(using: .utf8)
    }
}
