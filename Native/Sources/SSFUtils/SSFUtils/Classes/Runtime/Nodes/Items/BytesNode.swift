import Foundation

public class BytesNode: Node {
    public var typeName: String { GenericType.bytes.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendVector(
            json: value,
            type: PrimitiveType.u8.name
        )
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readVector(type: PrimitiveType.u8.name)
    }
}
