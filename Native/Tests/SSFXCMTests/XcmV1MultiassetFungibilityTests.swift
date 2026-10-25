import BigInt
import XCTest

@testable import SSFXCM

final class XcmV1MultiassetFungibilityTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let fungibility = XcmV1MultiassetFungibility.fungible(amount: BigUInt())

        // act
        let encodedData = try JSONEncoder().encode(fungibility)

        // assert
        XCTAssertEqual(encodedData, TestData.fungibilityData)
    }
}

extension XcmV1MultiassetFungibilityTests {
    enum TestData {
        static let fungibilityData = """
        ["Fungible","0"]
        """.data(using: .utf8)
    }
}
