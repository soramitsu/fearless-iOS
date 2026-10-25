import Foundation

public class VectorNode: Node {
    public let typeName: String
    public let underlying: Node

    public init(typeName: String, underlying: Node) {
        self.typeName = typeName
        self.underlying = underlying
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendVector(json: value, type: underlying.typeName)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readVector(type: underlying.typeName)
    }
}
