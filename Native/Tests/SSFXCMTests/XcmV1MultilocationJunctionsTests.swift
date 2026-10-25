import XCTest

@testable import SSFXCM

final class XcmV1MultilocationJunctionsTests: XCTestCase {
    func testXcmV1MultilocationJunctionsInit() {
        // arrange
        let items: [XcmJunction] = [.onlyChild]

        // act
        let junctions = XcmV1MultilocationJunctions(items: items)

        // assert
        XCTAssertEqual(junctions.items, items)
    }

    func testEncode() throws {
        // arrange
        let junctions = XcmV1MultilocationJunctions(items: [.onlyChild])

        // act
        let encodedData = try JSONEncoder().encode(junctions)

        // assert
        XCTAssertEqual(encodedData, TestData.junctionsData)
    }
}

extension XcmV1MultilocationJunctionsTests {
    enum TestData {
        static let junctionsData = """
        ["X1",["OnlyChild",null]]
        """.data(using: .utf8)
    }
}
