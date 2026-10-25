import Foundation

public class ExtrinsicsDecoderNode: Node {
    public var typeName: String { GenericType.extrinsicDecoder.name }

    public init() {}

    public func accept(encoder _: DynamicScaleEncoding, value _: JSON) throws {}

    public func accept(decoder _: DynamicScaleDecoding) throws -> JSON { .null }
}
