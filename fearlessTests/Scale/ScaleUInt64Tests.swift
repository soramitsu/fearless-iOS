import XCTest
@testable import fearless

class ScaleUInt64Tests: XCTestCase {
    private struct TestExample {
        let value: UInt64
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 578437695752307201, result: Data([1, 2, 3, 4, 5, 6, 7, 8])),
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
            let value = try UInt64(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
