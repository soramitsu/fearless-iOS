import Foundation

public class FixedArrayNode: Node {
    public let typeName: String
    public let elementType: Node
    public let length: UInt64

    public init(typeName: String, elementType: Node, length: UInt64) {
        self.typeName = typeName
        self.elementType = elementType
        self.length = length
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let items = value.arrayValue else {
            throw DynamicScaleEncoderError.arrayExpected(json: value)
        }

        // Fixed arrays have no length prefix, so a short or long input would silently shift every
        // field that follows it.
        guard UInt64(items.count) == length else {
            throw DynamicScaleEncoderError.unexpectedFixedArrayLength(
                expected: length,
                actual: items.count
            )
        }

        try encoder.appendFixedArray(json: value, type: elementType.typeName)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readFixedArray(type: elementType.typeName, length: length)
    }
}
