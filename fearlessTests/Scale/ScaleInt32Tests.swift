import XCTest
@testable import fearless

class ScaleInt32Tests: XCTestCase {
    private struct TestExample {
        let value: Int32
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 2147483647, result: Data([255, 255, 255, 127])),
        TestExample(value: -1, result: Data([255, 255, 255, 255])),
        TestExample(value: 1, result: Data([1, 0, 0, 0]))
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
            let value = try Int32(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
