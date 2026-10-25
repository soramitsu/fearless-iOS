import BigInt
import XCTest

@testable import SSFXCM

final class XcmWeightLimitTests: XCTestCase {
    func testEncode() throws {
        // arrange
        let weight = XcmWeightLimit.unlimited

        // act
        let encodedData = try JSONEncoder().encode(weight)

        // assert: an enum value is `[variant, payload]`; a unit variant carries `null`
        XCTAssertEqual(encodedData, TestData.weightData)
    }

    func testDecodingIsRefusedInsteadOfCrashing() {
        XCTAssertThrowsError(try JSONDecoder().decode(XcmWeightLimit.self, from: Data("[]".utf8)))
    }
}

extension XcmWeightLimitTests {
    enum TestData {
        static let weightData = """
        ["Unlimited",null]
        """.data(using: .utf8)
    }
}
