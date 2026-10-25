import Foundation

public class EventRecordNode: Node {
    public var typeName: String { GenericType.eventRecord.name }
    public let runtimeMetadata: RuntimeMetadata

    public init(runtimeMetadata: RuntimeMetadata) {
        self.runtimeMetadata = runtimeMetadata
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let params = value.arrayValue, params.count == 3 else {
            throw DynamicScaleEncoderError.arrayExpected(json: value)
        }

        try encoder.append(json: params[0], type: KnownType.phase.name)
        try encoder.append(json: params[1], type: GenericType.event.name)
        try encoder.appendVector(json: params[2], type: GenericType.h256.name)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let phase = try decoder.read(type: KnownType.phase.name)
        let event = try decoder.read(type: GenericType.event.name)
        let topics = try decoder.readVector(type: GenericType.h256.name)

        return .arrayValue([phase, event, topics])
    }
}
