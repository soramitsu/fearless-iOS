import XCTest
@testable import fearless

class ScaleInt8Tests: XCTestCase {
    private struct TestExample {
        let value: Int8
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 0, result: Data([0])),
        TestExample(value: -1, result: Data([255])),
        TestExample(value: -128, result: Data([128])),
        TestExample(value: -127, result: Data([129])),
        TestExample(value: 123, result: Data([123])),
        TestExample(value: -15, result: Data([241]))
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
            let value = try Int8(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
