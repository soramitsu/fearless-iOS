import XCTest
@testable import fearless
import IrohaCrypto
import BigInt

class ScaleCompactIntTests: XCTestCase {
    private struct TestExample {
        let value: BigUInt
        let result: Data
    }

    private let testVectors: [TestExample] = [
        TestExample(value: BigUInt(0), result: Data([0])),
        TestExample(value: BigUInt(1), result: Data([4])),
        TestExample(value: BigUInt(63), result: Data([252])),
        TestExample(value: BigUInt(64), result: Data([1, 1])),
        TestExample(value: BigUInt(255), result: Data([253, 3])),
        TestExample(value: BigUInt(511), result: Data([253, 7])),
        TestExample(value: BigUInt(16383), result: Data([253, 255])),
        TestExample(value: BigUInt(16384), result: Data([2, 0, 1, 0])),
        TestExample(value: BigUInt(65535), result: Data([254, 255, 3, 0])),
        TestExample(value: BigUInt("1073741823"), result: Data([254, 255, 255, 255])),
        TestExample(value: BigUInt("1234567890123456789012345678901234567890"),
                    result: Data([0b110111, 210, 10, 63, 206, 150, 95, 188, 172, 184, 243, 219, 192,
                    117, 32, 201, 160, 3])),
        TestExample(value: BigUInt(1073741824), result: Data([3, 0, 0, 0, 64])),
        TestExample(value:
            BigUInt("224945689727159819140526925384299092943484855915095831655037778630591879033574393515952034305194542857496045531676044756160413302774714984450425759043258192756735"),
                    result:
            try! Data(hexString: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))
    ]

    func testCompactEncoding() throws {
        for test in testVectors {
            let encoder = ScaleEncoder()
            try test.value.encode(scaleEncoder: encoder)

            XCTAssertEqual(encoder.encode(), test.result)
        }
    }

    func testCompactDecoding() throws {
        for test in testVectors {
            let decoder = try ScaleDecoder(data: test.result)
            let value = try BigUInt(scaleDecoder: decoder)

            XCTAssertEqual(value, test.value)
        }
    }
}
