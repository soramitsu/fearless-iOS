import Foundation

public class NullNode: Node {
    public var typeName: String { GenericType.null.name }

    public init() {}

    public func accept(encoder _: DynamicScaleEncoding, value _: JSON) throws {}
    public func accept(decoder _: DynamicScaleDecoding) throws -> JSON {
        .null
    }
}
