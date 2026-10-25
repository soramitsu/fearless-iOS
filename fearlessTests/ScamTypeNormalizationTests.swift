import XCTest
@testable import fearless

final class ScamTypeNormalizationTests: XCTestCase {
    func testKnownCsvTypesNormalizeWhitespaceAndCase() {
        XCTAssertEqual(ScamInfo.ScamType(from: "Low network activity"), .lowScore)
        XCTAssertEqual(ScamInfo.ScamType(from: " LOW NETWORK ACTIVITY\n"), .lowScore)
        XCTAssertEqual(ScamInfo.ScamType(from: " SCAM "), .scam)
        XCTAssertEqual(ScamInfo.ScamType(from: "sanctions"), .sanctions)
        XCTAssertNil(ScamInfo.ScamType(from: "not-a-type"))
        XCTAssertNil(ScamInfo.ScamType(from: ""))
    }
}
