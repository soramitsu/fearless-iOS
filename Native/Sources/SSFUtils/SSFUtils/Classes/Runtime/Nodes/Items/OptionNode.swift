import Foundation

public class OptionNode: Node {
    public let typeName: String
    public let underlying: Node

    public init(typeName: String, underlying: Node) {
        self.typeName = typeName
        self.underlying = underlying
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendOption(json: value, type: underlying.typeName)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readOption(type: underlying.typeName)
    }
}
