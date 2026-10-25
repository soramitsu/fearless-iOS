import Foundation

public class EcdsaNode: Node {
    public var typeName: String { GenericType.ecdsa.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendBytes(json: value)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readBytes(length: 65)
    }
}
