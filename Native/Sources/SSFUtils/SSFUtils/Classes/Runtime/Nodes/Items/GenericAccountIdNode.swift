import Foundation

public class GenericAccountIdNode: Node {
    public var typeName: String { GenericType.accountId.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendBytes(json: value)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readBytes(length: 32)
    }
}
