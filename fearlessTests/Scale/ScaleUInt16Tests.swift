import XCTest
@testable import fearless

class ScaleUInt16Tests: XCTestCase {
    private struct TestExample {
        let value: UInt16
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 32767, result: Data([255, 127])),
        TestExample(value: 12345, result: Data([57, 48]))
    ]

    func testEncoding() throws {
        for test in testVectors {
            let encoder = ScaleEncoder()
            try test.value.encode(scaleEncoder: encoder)

            XCTAssertEqual(encoder.encode(), test.result)
        }
    }

    func testDecoding() throws {
        for test in testVectors {
            let decoder = try ScaleDecoder(data: test.result)
            let value = try UInt16(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
