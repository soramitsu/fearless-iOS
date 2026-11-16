import BigInt
@testable import fearless
import Foundation
import XCTest

final class CovGABIEncodingTests: XCTestCase {
    func testIntegerConversionSupportsSignedUnsignedDecimalAndHex() {
        let positives: [Any] = [BigUInt(42), BigInt(42), "42", "0x2a", UInt(42), UInt8(42), UInt16(42), UInt32(42), UInt64(42), Int(42), Int8(42), Int16(42), Int32(42), Int64(42)]
        for value in positives {
            XCTAssertEqual(ABIEncoder.convertToBigUInt(value as AnyObject), 42)
            XCTAssertEqual(ABIEncoder.convertToBigInt(value as AnyObject), 42)
        }
        for value in [BigInt(-42), Int(-42), Int8(-42), Int16(-42), Int32(-42), Int64(-42)] as [Any] {
            XCTAssertNil(ABIEncoder.convertToBigUInt(value as AnyObject))
            XCTAssertEqual(ABIEncoder.convertToBigInt(value as AnyObject), -42)
        }
        for value in ["invalid", NSObject()] as [Any] {
            XCTAssertNil(ABIEncoder.convertToBigUInt(value as AnyObject))
            XCTAssertNil(ABIEncoder.convertToBigInt(value as AnyObject))
        }
    }

    func testByteConversionPreservesDataTextAndAddresses() throws {
        let bytes = Data([1, 2, 255])
        for value in [bytes, [UInt8(1), 2, 255], [Int(1), 2, 255], "0x0102ff"] as [Any] {
            XCTAssertEqual(ABIEncoder.convertToData(value as AnyObject, type: .dynamicBytes), bytes)
        }
        XCTAssertEqual(ABIEncoder.convertToData("text" as AnyObject, type: .string), Data("text".utf8))
        XCTAssertEqual(ABIEncoder.convertToData("42" as AnyObject, type: .uint(bits: 256)), Data([42]))
        XCTAssertNil(ABIEncoder.convertToData("invalid" as AnyObject, type: .uint(bits: 256)))
        XCTAssertNil(ABIEncoder.convertToData([256, -1] as AnyObject, type: .dynamicBytes))
        XCTAssertNil(ABIEncoder.convertToData(NSObject(), type: .dynamicBytes))
        let address = try XCTUnwrap(Address(address: "0x1111111111111111111111111111111111111111"))
        XCTAssertEqual(ABIEncoder.convertToData(address as AnyObject, type: .address), Data(repeating: 17, count: 20))
    }

    func testScalarEncodingsMatchABIWords() throws {
        for type in [ABI.Element.ParameterType.uint(bits: 256), .int(bits: 256)] {
            XCTAssertEqual(ABIEncoder.encodeSingleType(type: type, value: BigUInt(42) as AnyObject), word(42))
            XCTAssertNil(ABIEncoder.encodeSingleType(type: type, value: NSObject()))
        }
        XCTAssertEqual(ABIEncoder.encodeSingleType(type: .int(bits: 256), value: BigInt(-1) as AnyObject), Data(repeating: 255, count: 32))
        XCTAssertEqual(ABIEncoder.encodeSingleType(type: .bool, value: true as AnyObject), word(1))
        XCTAssertEqual(ABIEncoder.encodeSingleType(type: .bool, value: false as AnyObject), word(0))
        XCTAssertEqual(ABIEncoder.encodeSingleType(type: .bytes(length: 2), value: Data([1, 2]) as AnyObject), Data([1, 2]) + Data(repeating: 0, count: 30))
        XCTAssertNil(ABIEncoder.encodeSingleType(type: .bytes(length: 1), value: Data([1, 2]) as AnyObject))
        let addressBytes = Data(repeating: 17, count: 20)
        let address = try XCTUnwrap(Address(data: addressBytes))
        for value in [addressBytes, address, "0x1111111111111111111111111111111111111111"] as [Any] {
            XCTAssertEqual(ABIEncoder.encodeSingleType(type: .address, value: value as AnyObject), Data(repeating: 0, count: 12) + addressBytes)
        }
        XCTAssertEqual(ABIEncoder.encodeSingleType(type: .address, value: "invalid" as AnyObject), Data(repeating: 0, count: 32))
        XCTAssertEqual(ABIEncoder.encodeSingleType(type: .function, value: Data([1, 2]) as AnyObject), Data(repeating: 0, count: 30) + Data([1, 2]))
        XCTAssertNil(ABIEncoder.encodeSingleType(type: .function, value: NSObject()))
    }

    func testDynamicStringAndBytesUseOffsetsLengthsAndPadding() throws {
        let expected = word(32) + word(2) + Data([104, 105]) + Data(repeating: 0, count: 30)
        for (type, value) in [(ABI.Element.ParameterType.string, "hi" as AnyObject), (.string, "0x6869" as AnyObject), (.dynamicBytes, Data([104, 105]) as AnyObject)] {
            XCTAssertEqual(ABIEncoder.encode(types: [type], values: [value]), expected)
        }
        XCTAssertNil(ABIEncoder.encode(types: [ABI.Element.ParameterType.string], values: []))
        XCTAssertNil(ABIEncoder.encodeSingleType(type: .string, value: NSObject()))
        XCTAssertNil(ABIEncoder.encodeSingleType(type: .dynamicBytes, value: NSObject()))
        XCTAssertEqual(try XCTUnwrap(ABIDecoder.decode(types: [ABI.Element.ParameterType.string], data: expected)).first as? String, "hi")
        XCTAssertEqual(try XCTUnwrap(ABIDecoder.decode(types: [ABI.Element.ParameterType.dynamicBytes], data: expected)).first as? Data, Data([104, 105]))
    }

    func testStaticAndDynamicArraysAndTuplesRoundTrip() throws {
        let integers = [BigUInt(1), BigUInt(2)] as [AnyObject]
        for length in [UInt64(0), 2] {
            let type = ABI.Element.ParameterType.array(type: .uint(bits: 256), length: length)
            let encoded = try XCTUnwrap(ABIEncoder.encode(types: [type], values: [integers as AnyObject]))
            XCTAssertEqual(encoded, (length == 0 ? word(32) + word(2) : Data()) + word(1) + word(2))
            let decoded = try XCTUnwrap(ABIDecoder.decode(types: [type], data: encoded))
            XCTAssertEqual(decoded.first as? [BigUInt], [1, 2])
        }
        for length in [UInt64(0), 2] {
            let type = ABI.Element.ParameterType.array(type: .string, length: length)
            let encoded = try XCTUnwrap(ABIEncoder.encode(types: [type], values: [["first", "second"] as AnyObject]))
            let decoded = try XCTUnwrap(ABIDecoder.decode(types: [type], data: encoded))
            XCTAssertEqual(decoded.first as? [String], ["first", "second"])
        }
        let type = ABI.Element.ParameterType.tuple(types: [.uint(bits: 256), .string])
        let encoded = try XCTUnwrap(ABIEncoder.encode(types: [type], values: [[BigUInt(42), "answer"] as AnyObject]))
        let decoded = try XCTUnwrap(ABIDecoder.decode(types: [type], data: encoded)?.first as? [AnyObject])
        XCTAssertEqual(decoded[0] as? BigUInt, 42)
        XCTAssertEqual(decoded[1] as? String, "answer")
        XCTAssertNil(ABIEncoder.encodeSingleType(type: .array(type: .bool, length: 2), value: [true] as AnyObject))
        XCTAssertNil(ABIEncoder.encodeSingleType(type: .array(type: .bool, length: 0), value: NSObject()))
    }

    func testDecoderRejectsTruncationInvalidBoolAndBadDynamicOffsets() {
        for type in [ABI.Element.ParameterType.uint(bits: 256), .int(bits: 256), .address, .bool, .bytes(length: 2), .string, .dynamicBytes, .function] {
            XCTAssertNil(ABIDecoder.decode(types: [type], data: Data()))
        }
        XCTAssertNil(ABIDecoder.decode(types: [ABI.Element.ParameterType.bool], data: word(2)))
        XCTAssertNil(ABIDecoder.decode(types: [ABI.Element.ParameterType.string], data: word(96)))
        XCTAssertNil(ABIDecoder.decode(types: [ABI.Element.ParameterType.string], data: word(32) + word(8)))
        XCTAssertNil(ABIDecoder.decode(types: [ABI.Element.ParameterType.dynamicBytes], data: word(32) + word(8)))
        for (value, expected) in [(UInt8(0), false), (1, true), (27, false), (28, true), (31, false), (32, true), (35, false), (36, true)] {
            XCTAssertEqual(ABIDecoder.decode(types: [ABI.Element.ParameterType.bool], data: word(value))?.first as? Bool, expected)
        }
        XCTAssertEqual(ABIDecoder.decode(types: [ABI.Element.ParameterType.int(bits: 256)], data: Data(repeating: 255, count: 32))?.first as? BigInt, -1)
        XCTAssertEqual(ABIDecoder.decode(types: [ABI.Element.ParameterType.bytes(length: 2)], data: Data([1, 2]) + Data(repeating: 0, count: 30))?.first as? Data, Data([1, 2]))
    }

    private func word(_ value: UInt8) -> Data {
        Data(repeating: 0, count: 31) + Data([value])
    }
}

final class CovGABIParsingTests: XCTestCase {
    func testTypeParsingAliasesArraysAndInvalidSyntax() throws {
        let cases: [(String, ABI.Element.ParameterType)] = [
            ("uint", .uint(bits: 256)), ("int", .int(bits: 256)), ("uint8", .uint(bits: 8)), ("address", .address),
            ("bool", .bool), ("bytes4", .bytes(length: 4)), ("bytes", .dynamicBytes), ("string", .string),
            ("uint32[2][]", .array(type: .array(type: .uint(bits: 32), length: 2), length: 0)),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(try ABITypeParser.parseTypeString(input), expected)
        }
        for input in ["", "nonsense", "uint0", "uint256garbage", "bytes[invalid]", "uint8[0]"] {
            XCTAssertThrowsError(try ABITypeParser.parseTypeString(input))
        }
    }

    func testFunctionConstructorEventAndFallbackRecords() throws {
        let function = try parse(#"{"name":"read","stateMutability":"view","inputs":[{"name":"arg","type":"uint256"}],"outputs":[{"name":"value","type":"bool"}]}"#)
        guard case let .function(value) = function else { return XCTFail("Expected function") }
        XCTAssertEqual(value.signature, "read(uint256)")
        XCTAssertTrue(value.constant)
        XCTAssertFalse(value.payable)
        XCTAssertEqual(value.inputs.first?.name, "arg")
        XCTAssertEqual(value.outputs.first?.type, .bool)
        guard case let .constructor(constructor) = try parse(#"""
        {"type":"constructor",
        "payable":true,
        "inputs":[{"type":"address"}]}
        """#) else { return XCTFail("Expected constructor") }
        XCTAssertTrue(constructor.payable)
        XCTAssertFalse(constructor.constant)
        XCTAssertEqual(constructor.inputs.first?.name, "")
        guard case let .fallback(fallback) = try parse(#"{"type":"fallback","payable":false,"stateMutability":"pure"}"#) else { return XCTFail("Expected fallback") }
        XCTAssertTrue(fallback.constant)
        XCTAssertFalse(fallback.payable)
        guard case let .event(event) = try parse(#"""
        {"type":"event",
        "name":"Changed",
        "anonymous":true,
        "inputs":[{"name":"who",
        "type":"address",
        "indexed":true}]}
        """#) else { return XCTFail("Expected event") }
        XCTAssertEqual(event.signature, "Changed(address)")
        XCTAssertTrue(event.anonymous)
        XCTAssertTrue(event.inputs[0].indexed)
        XCTAssertThrowsError(try parse(#"{"type":"unknown"}"#))
    }

    func testTupleRecordComponentsArePreserved() throws {
        let json = #"""
        {"inputs":[{"type":"tuple",
        "components":[{"type":"bool"},
        {"type":"uint8"}]}],
        "outputs":[{"type":"tuple[]",
        "components":[{"type":"address"}]},
        {"type":"tuple",
        "components":[{"type":"string"}]}]}
        """#
        guard case let .function(value) = try parse(json) else { return XCTFail("Expected function") }
        XCTAssertEqual(value.inputs.first?.type.abiRepresentation, "tuple(bool,uint8)")
        XCTAssertEqual(value.outputs.map { $0.type.abiRepresentation }, ["tuple(address)[]", "tuple(string)"])
        guard case let .function(empty) = try parse("{}") else { return XCTFail("Expected function") }
        XCTAssertEqual(empty.signature, "()")
        XCTAssertTrue(empty.inputs.isEmpty)
        XCTAssertTrue(empty.outputs.isEmpty)
    }

    func testParameterPropertiesDescribeLayoutAndValidation() {
        let types: [(ABI.Element.ParameterType, String, Bool, UInt64)] = [
            (.uint(bits: 8), "uint8", true, 32), (.int(bits: 16), "int16", true, 32), (.address, "address", true, 32),
            (.function, "function", true, 32), (.bool, "bool", true, 32), (.bytes(length: 2), "bytes2", true, 32),
            (.dynamicBytes, "bytes", false, 32), (.string, "string", false, 32),
            (.array(type: .bool, length: 2), "bool[2]", true, 64), (.array(type: .bool, length: 0), "bool[]", false, 32),
            (.array(type: .string, length: 2), "string[2]", false, 32),
            (.tuple(types: [.bool, .uint(bits: 8)]), "tuple(bool,uint8)", true, 64),
            (.tuple(types: [.string]), "tuple(string)", false, 32),
        ]
        for (type, representation, isStatic, memory) in types {
            XCTAssertEqual(type.abiRepresentation, representation)
            XCTAssertEqual(type.isStatic, isStatic)
            XCTAssertEqual(type.memoryUsage, memory)
            XCTAssertTrue(type.isValid)
            XCTAssertEqual(type.isNumber, representation.hasPrefix("uint") || representation.hasPrefix("int"))
            XCTAssertEqual(type.isTuple, representation.hasPrefix("tuple"))
            XCTAssertEqual(type.isArray, representation.hasSuffix("]"))
            if type.isArray {
                XCTAssertNotNil(type.subtype)
            } else {
                XCTAssertNil(type.subtype)
            }
        }
        for type in [ABI.Element.ParameterType.uint(bits: 0), .int(bits: 257), .uint(bits: 7), .bytes(length: 33), .bytes(length: 0), .tuple(types: [.uint(bits: 0)])] {
            XCTAssertFalse(type.isValid)
        }
        XCTAssertEqual(ABI.Element.ParameterType.string.emptyValue as? String, "")
        XCTAssertEqual(ABI.Element.ParameterType.bool.emptyValue as? Bool, false)
        XCTAssertEqual(ABI.Element.ParameterType.bytes(length: 2).emptyValue as? Data, Data([0, 0]))
        XCTAssertEqual(ABI.Element.ParameterType.dynamicBytes.emptyValue as? Data, Data())
        XCTAssertEqual(ABI.Element.ParameterType.array(type: .uint(bits: 8), length: 2).emptyValue as? [BigUInt], [0, 0])
        XCTAssertTrue((ABI.Element.ParameterType.tuple(types: []).emptyValue as? [Any])?.isEmpty == true)
    }

    func testERC20MethodEncodingAndNamedDecoding() throws {
        let function = ABI.Element.Function.erc20transfer
        XCTAssertEqual(function.signature, "transfer(address,uint256)")
        XCTAssertEqual(function.methodString, "a9059cbb")
        let element = ABI.Element.function(function)
        let encoded = try XCTUnwrap(element.encodeParameters(["0x1111111111111111111111111111111111111111" as AnyObject, BigUInt(42) as AnyObject]))
        XCTAssertEqual(encoded.prefix(4), Data([0xA9, 0x05, 0x9C, 0xBB]))
        let decoded = try XCTUnwrap(element.decodeInputData(encoded))
        XCTAssertEqual(decoded["value"] as? BigUInt, 42)
        XCTAssertEqual(decoded["1"] as? BigUInt, 42)
        XCTAssertEqual((decoded["to"] as? Address)?.data, Data(repeating: 17, count: 20))
        XCTAssertEqual(element.decodeReturnData(Data(repeating: 0, count: 31) + Data([1]))?["success"] as? Bool, true)
        XCTAssertEqual(element.decodeReturnData(Data())?["success"] as? Bool, false)
        XCTAssertNil(element.encodeParameters([]))
        XCTAssertNil(element.decodeInputData(Data([1])))
        XCTAssertNil(element.decodeInputData(Data(repeating: 0, count: 68)))
        let method = try XCTUnwrap(ABI.ContractCollection.erc20.methods[.transfer])
        let dictionary: [String: AnyObject] = ["value": BigUInt(42) as AnyObject, "other": "ignored" as AnyObject]
        XCTAssertEqual(dictionary.inputs(for: method)?[.value] as? BigUInt, 42)
        XCTAssertNil([String: AnyObject]().inputs(for: method))
    }

    func testNonFunctionElementsRejectReturnDataAndNonCallableElementsRejectInput() throws {
        let elements: [ABI.Element] = [
            .constructor(.init(inputs: [], constant: false, payable: true)),
            .fallback(.init(constant: false, payable: false)), .event(.init(name: "Event", inputs: [], anonymous: false)),
        ]
        for element in elements {
            XCTAssertNil(element.decodeReturnData(Data()))
        }
        for element in elements.dropFirst() {
            XCTAssertNil(element.encodeParameters([]))
            XCTAssertNil(element.decodeInputData(Data()))
        }
        let constructor = ABI.Element.constructor(.init(inputs: [.init(name: "value", type: .uint(bits: 256))], constant: false, payable: false))
        let bytes = try XCTUnwrap(constructor.encodeParameters([BigUInt(9) as AnyObject]))
        XCTAssertEqual(constructor.decodeInputData(bytes)?["value"] as? BigUInt, 9)
        XCTAssertEqual(constructor.decodeInputData(Data())?["value"] as? BigUInt, 0)
        XCTAssertNil(constructor.encodeParameters([]))
    }

    private func parse(_ json: String) throws -> ABI.Element {
        try JSONDecoder().decode(ABI.Record.self, from: Data(json.utf8)).parse()
    }
}
