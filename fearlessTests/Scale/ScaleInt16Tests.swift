import XCTest
@testable import fearless

class ScaleInt16Tests: XCTestCase {
    private struct TestExample {
        let value: Int16
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: -32767, result: Data([1, 128])),
        TestExample(value: -32768, result: Data([0, 128])),
        TestExample(value: -1, result: Data([255, 255])),
        TestExample(value: 32767, result: Data([255, 127])),
        TestExample(value: 12345, result: Data([57, 48])),
        TestExample(value: -12345, result: Data([199, 207]))
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
            let value = try Int16(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
