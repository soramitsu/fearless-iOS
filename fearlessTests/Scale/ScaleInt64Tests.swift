import XCTest
@testable import fearless

class ScaleInt64Tests: XCTestCase {
    private struct TestExample {
        let value: Int64
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 578437695752307201, result: Data([1, 2, 3, 4, 5, 6, 7, 8])),
        TestExample(value: -1, result: Data([255, 255, 255, 255, 255, 255, 255, 255]))
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
            let value = try Int64(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
