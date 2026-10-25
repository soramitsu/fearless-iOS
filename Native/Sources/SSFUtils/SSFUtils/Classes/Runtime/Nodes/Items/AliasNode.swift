import Foundation

public class AliasNode: Node {
    public let typeName: String
    public let underlyingTypeName: String

    public init(typeName: String, underlyingTypeName: String) {
        self.typeName = typeName
        self.underlyingTypeName = underlyingTypeName
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.append(json: value, type: underlyingTypeName)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.read(type: underlyingTypeName)
    }
}
