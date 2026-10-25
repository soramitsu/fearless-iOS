import Foundation

public class CompactNode: Node {
    public let typeName: String
    public let underlying: Node

    public init(typeName: String, underlying: Node) {
        self.typeName = typeName
        self.underlying = underlying
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendCompact(json: value, type: underlying.typeName)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readCompact(type: underlying.typeName)
    }
}
