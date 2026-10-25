import Foundation

public class GenericConsensusEngineIdNode: Node {
    public var typeName: String { GenericType.consensusEngineId.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        try encoder.appendBytes(json: value)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        try decoder.readBytes(length: 4)
    }
}
