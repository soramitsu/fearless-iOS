import XCTest

@testable import SSFXCM

final class GeneralKeyV3Tests: XCTestCase {
    func testGeneralKeyV3Init() {
        // arrange
        let length: UInt32 = 0
        let data = Data()

        // act
        let generalKeyV3 = GeneralKeyV3(lengh: length, data: data)

        // assert
        XCTAssertNotNil(generalKeyV3)
        XCTAssertEqual(generalKeyV3.length, length)
        XCTAssertEqual(generalKeyV3.data, data)
    }

    func testInitFromDecoder() throws {
        // act
        let key = try JSONDecoder().decode(
            GeneralKeyV3.self,
            from: TestData.generalKeyData ?? Data()
        )

        // assert
        XCTAssertEqual(key.length, 4)
        XCTAssertEqual(key.data.toHex(), "68656c6c6f")
    }
}

extension GeneralKeyV3Tests {
    enum TestData {
        static let generalKeyData = """
        {"length": 4,"data": "68656c6c6f"}
        """.data(using: .utf8)
    }
}
