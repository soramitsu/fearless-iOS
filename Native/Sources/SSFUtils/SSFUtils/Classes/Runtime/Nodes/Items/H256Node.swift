import Foundation

public class H256Node: Node {
    public var typeName: String { GenericType.h256.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendBytes(json: value, expectedLength: 32)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readBytes(length: 32)
    }
}
