import Foundation

public class CallBytesNode: Node {
    public var typeName: String { GenericType.callBytes.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendBytes(json: value)
    }

    public func accept(decoder _: DynamicScaleDecoding) throws -> JSON {
        throw DynamicScaleCoderError.notImplemented
    }
}
