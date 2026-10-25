import Foundation

public enum DynamicScaleCoderError: Error {
    case unresolvedType(name: String)
    case notImplemented
    case invalidParams
}

public enum DynamicScaleEncoderError: Error {
    case arrayExpected(json: JSON)
    case dictExpected(json: JSON)
    case unsignedIntExpected(json: JSON)
    case unexpectedNull
    case hexExpected(json: JSON)
    case expectedStringForCompact(json: JSON)
    case expectedStringForInt(json: JSON)
    case expectedStringForBool(json: JSON)
    case missingOptionModifier
    case unexpectedStructFields(json: JSON, expectedFields: [String])
    case unexpectedEnumJSON(json: JSON)
    case unexpectedEnumCase(value: String)
    case unexpectedEnumValues(value: UInt64, count: Int)
    case unexpectedTupleJSON(json: JSON)
    case unexpectedTupleComponents(count: Int, actual: Int)
    case stringExpected(json: JSON)
    case integerOutOfRange(value: String, byteLength: Int, signed: Bool)
    case unexpectedFixedArrayLength(expected: UInt64, actual: Int)
}

public enum DynamicScaleDecoderError: Error {
    case unexpectedOption(byte: UInt8)
    case unexpectedEnumCase
    case invalidEnumCase(index: UInt8)
    case invalidCustomEnumCase(value: Int, count: Int)
}
