import XCTest
@testable import fearless

class ScaleStringTests: XCTestCase {
    private struct TestExample {
        let value: String
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: "asdadad", result: Data([28]) + "asdadad".data(using: .utf8)!),
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
            let value = try String(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
