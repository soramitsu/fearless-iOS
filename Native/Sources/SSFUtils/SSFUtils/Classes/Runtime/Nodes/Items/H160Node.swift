import Foundation

public class H160Node: Node {
    public var typeName: String { GenericType.h160.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendBytes(json: value, expectedLength: 20)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readBytes(length: 20)
    }
}
