import Foundation

public class GenericNode: Node {
    public let typeName: String

    public init(typeName: String) {
        self.typeName = typeName
    }

    public func accept(encoder _: DynamicScaleEncoding, value _: JSON) throws {
        throw DynamicScaleCoderError.unresolvedType(name: typeName)
    }

    public func accept(decoder _: DynamicScaleDecoding) throws -> JSON {
        throw DynamicScaleCoderError.unresolvedType(name: typeName)
    }
}
