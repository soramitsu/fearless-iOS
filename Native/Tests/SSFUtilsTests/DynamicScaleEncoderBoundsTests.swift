import BigInt
import XCTest

@testable import SSFUtils

/// A value that does not fit its SCALE type must be refused. Padding or passing it through would
/// change the length of the call and shift every field that follows.
final class DynamicScaleEncoderBoundsTests: XCTestCase {
    private var runtime: FixtureRuntime!

    override func setUpWithError() throws {
        try super.setUpWithError()
        runtime = try FixtureRuntime(.polkadotAssetHub)
    }

    // MARK: - Unsigned integers

    func testUnsignedIntegersAcceptTheirLargestValue() throws {
        let cases: [(
            append: (DynamicScaleEncoder) -> (JSON) throws -> Void,
            max: String,
            bytes: Int
        )] = [
            ({ $0.appendU8 }, "255", 1),
            ({ $0.appendU16 }, "65535", 2),
            ({ $0.appendU32 }, "4294967295", 4),
            ({ $0.appendU64 }, "18446744073709551615", 8),
            ({ $0.appendU128 }, String(BigUInt(2).power(128) - 1), 16),
            ({ $0.appendU256 }, String(BigUInt(2).power(256) - 1), 32),
        ]

        for (append, max, bytes) in cases {
            let encoder = runtime.encoder()
            try append(encoder)(.stringValue(max))

            XCTAssertEqual(try encoder.encode(), Data(repeating: 0xFF, count: bytes), "max \(max)")
        }
    }

    func testUnsignedIntegersRefuseTheFirstValueThatDoesNotFit() {
        let cases: [(append: (DynamicScaleEncoder) -> (JSON) throws -> Void, bytes: Int)] = [
            ({ $0.appendU8 }, 1),
            ({ $0.appendU16 }, 2),
            ({ $0.appendU32 }, 4),
            ({ $0.appendU64 }, 8),
            ({ $0.appendU128 }, 16),
            ({ $0.appendU256 }, 32),
        ]

        for (append, bytes) in cases {
            let overflow = String(BigUInt(2).power(bytes * 8))
            let encoder = runtime.encoder()

            XCTAssertThrowsError(try append(encoder)(.stringValue(overflow)), "2^\(bytes * 8)") {
                guard case let DynamicScaleEncoderError
                    .integerOutOfRange(value, length, signed) = $0 else
                {
                    return XCTFail("Expected integerOutOfRange, got \($0)")
                }

                XCTAssertEqual(value, overflow)
                XCTAssertEqual(length, bytes)
                XCTAssertFalse(signed)
            }
            XCTAssertEqual(try? encoder.encode(), Data(), "nothing may be written for \(overflow)")
        }
    }

    func testAnAmountOfTwoToTheHundredAndTwentyEightPlusFiveIsNotSeventeenBytes() throws {
        let amount = String(BigUInt(2).power(128) + 5)
        let encoder = runtime.encoder()

        XCTAssertThrowsError(try encoder.appendU128(json: .stringValue(amount)))
        XCTAssertEqual(try encoder.encode(), Data())
    }

    func testSmallUnsignedValuesStayLittleEndianAndPadded() throws {
        let encoder = runtime.encoder()
        try encoder.appendU32(json: .stringValue("258"))
        try encoder.appendU128(json: .stringValue("0"))

        XCTAssertEqual(try encoder.encode(), Data([2, 1, 0, 0] + Array(repeating: 0, count: 16)))
    }

    // MARK: - Signed integers

    func testSignedIntegersEncodeTwosComplement() throws {
        let encoder = runtime.encoder()
        try encoder.appendI8(json: .stringValue("-1"))
        try encoder.appendI8(json: .stringValue("-128"))
        try encoder.appendI8(json: .stringValue("127"))
        try encoder.appendI16(json: .stringValue("-2"))
        try encoder.appendI32(json: .stringValue("-2147483648"))
        try encoder.appendI64(json: .stringValue("1"))
        try encoder.appendI128(json: .stringValue("-1"))

        let expected = Data(
            [0xFF, 0x80, 0x7F]
                + [0xFE, 0xFF]
                + [0x00, 0x00, 0x00, 0x80]
                + [1, 0, 0, 0, 0, 0, 0, 0]
                + Array(repeating: 0xFF, count: 16)
        )
        XCTAssertEqual(try encoder.encode(), expected)
    }

    func testSignedIntegersRefuseValuesOutsideTheirRange() {
        let cases: [(append: (DynamicScaleEncoder) -> (JSON) throws -> Void, bytes: Int)] = [
            ({ $0.appendI8 }, 1),
            ({ $0.appendI16 }, 2),
            ({ $0.appendI32 }, 4),
            ({ $0.appendI64 }, 8),
            ({ $0.appendI128 }, 16),
            ({ $0.appendI256 }, 32),
        ]

        for (append, bytes) in cases {
            let bound = BigUInt(2).power(bytes * 8 - 1)
            for value in [String(bound), "-" + String(bound + 1)] {
                let encoder = runtime.encoder()

                XCTAssertThrowsError(
                    try append(encoder)(.stringValue(value)),
                    "\(bytes) bytes: \(value)"
                ) {
                    guard case DynamicScaleEncoderError.integerOutOfRange(_, bytes, true) = $0 else {
                        return XCTFail("Expected integerOutOfRange, got \($0)")
                    }
                }
            }
        }
    }

    // MARK: - Fixed arrays

    func testAnAccountThatIsNotThirtyTwoBytesIsRefused() throws {
        // AccountId32 is [u8; 32]. With 20 bytes the call used to encode, 12 bytes short.
        for length in [0, 20, 31, 33, 64] {
            let call = JSON.call("Balances", "transfer_keep_alive", [
                "dest": .variant("Id", .bytes(Data(repeating: 7, count: length))),
                "value": .stringValue("1"),
            ])

            XCTAssertThrowsError(try runtime.encode(call: call), "\(length) bytes") {
                guard case let DynamicScaleEncoderError.unexpectedFixedArrayLength(
                    expected,
                    actual
                ) = $0 else {
                    return XCTFail("Expected unexpectedFixedArrayLength, got \($0)")
                }

                XCTAssertEqual(expected, 32)
                XCTAssertEqual(actual, length)
            }
        }
    }

    func testAFixedArrayOfTheRightLengthEncodesAsBefore() throws {
        let node = FixedArrayNode(typeName: "[u8; 4]", elementType: U8Node(), length: 4)
        let encoder = runtime.encoder()

        try node.accept(encoder: encoder, value: .bytes(Data([9, 8, 7, 6])))

        XCTAssertEqual(try encoder.encode(), Data([9, 8, 7, 6]))
        XCTAssertThrowsError(try node.accept(
            encoder: runtime.encoder(),
            value: .stringValue("0x09080706")
        )) {
            guard case DynamicScaleEncoderError.arrayExpected = $0 else {
                return XCTFail("Expected arrayExpected, got \($0)")
            }
        }
    }

    func testHashesMustHaveTheirFullLength() throws {
        let nodes: [(node: Node, length: Int)] = [
            (H160Node(), 20),
            (H256Node(), 32),
            (H512Node(), 64),
        ]

        for (node, length) in nodes {
            let exact = "0x" + String(repeating: "ab", count: length)
            let encoder = runtime.encoder()
            try node.accept(encoder: encoder, value: .stringValue(exact))
            XCTAssertEqual(try encoder.encode(), Data(repeating: 0xAB, count: length))

            for wrong in [length - 1, length + 1, 0] {
                let value = "0x" + String(repeating: "ab", count: wrong)

                XCTAssertThrowsError(
                    try node.accept(encoder: runtime.encoder(), value: .stringValue(value)),
                    "\(node.typeName) with \(wrong) bytes"
                ) {
                    guard case let DynamicScaleEncoderError.unexpectedFixedArrayLength(
                        expected,
                        actual
                    ) = $0 else {
                        return XCTFail("Expected unexpectedFixedArrayLength, got \($0)")
                    }

                    XCTAssertEqual(expected, UInt64(length))
                    XCTAssertEqual(actual, wrong)
                }
            }

            XCTAssertThrowsError(
                try node.accept(encoder: runtime.encoder(), value: .stringValue("not hex"))
            ) {
                guard case DynamicScaleEncoderError.hexExpected = $0 else {
                    return XCTFail("Expected hexExpected, got \($0)")
                }
            }
        }
    }
}
