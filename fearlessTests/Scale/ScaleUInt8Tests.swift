import XCTest
@testable import fearless

class ScaleUInt8Tests: XCTestCase {
    private struct TestExample {
        let value: UInt8
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 0, result: Data([0])),
        TestExample(value: 234, result: Data([234])),
        TestExample(value: 255, result: Data([255]))
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
            let value = try UInt8(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
