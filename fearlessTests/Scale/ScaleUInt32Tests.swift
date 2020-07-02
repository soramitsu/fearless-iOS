import XCTest
@testable import fearless

class ScaleUInt32Tests: XCTestCase {
    private struct TestExample {
        let value: UInt32
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: 16909060, result: Data([4, 3, 2, 1])),
        TestExample(value: 67305985, result: Data([1, 2, 3, 4]))
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
            let value = try UInt32(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
