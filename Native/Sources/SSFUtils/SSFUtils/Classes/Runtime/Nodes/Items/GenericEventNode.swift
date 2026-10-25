import Foundation

public enum GenericEventNodeError: Error {
    case unexpectedParams
    case unexpectedEventModule(value: UInt64)
    case unexpectedEventIndex(value: UInt64)
    case argumentsNotMatchingParams(arguments: [String], params: [JSON])
    case unexpectedDecodedModule
    case unexpectedDecodedEventIndex
}

public class GenericEventNode: Node {
    public var typeName: String { GenericType.event.name }
    public let runtimeMetadata: RuntimeMetadata

    public init(runtimeMetadata: RuntimeMetadata) {
        self.runtimeMetadata = runtimeMetadata
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let input = value.arrayValue else {
            throw DynamicScaleEncoderError.arrayExpected(json: value)
        }

        guard input.count == 3,
              let eventModule = input[0].unsignedIntValue,
              let eventIndex = input[1].unsignedIntValue,
              let params = input[2].arrayValue else
        {
            throw GenericEventNodeError.unexpectedParams
        }

        guard let module = runtimeMetadata.modules.first(where: { $0.index == eventModule }) else {
            throw GenericEventNodeError.unexpectedEventModule(value: eventModule)
        }

        guard let index = UInt8(exactly: eventIndex),
              let event = try runtimeMetadata.getEvent(in: module, at: index) else
        {
            throw GenericEventNodeError.unexpectedEventIndex(value: eventIndex)
        }

        let arguments = event.arguments

        guard arguments.count == params.count else {
            throw GenericEventNodeError.argumentsNotMatchingParams(
                arguments: arguments,
                params: params
            )
        }

        try encoder.appendU8(json: .stringValue(String(eventModule)))
        try encoder.appendU8(json: .stringValue(String(eventIndex)))

        for index in 0 ..< arguments.count {
            try encoder.append(json: params[index], type: arguments[index])
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let eventModuleString = try (decoder.readU8()).stringValue,
              let eventModule = UInt8(eventModuleString) else
        {
            throw GenericEventNodeError.unexpectedDecodedModule
        }

        guard let eventString = try (decoder.readU8()).stringValue,
              let eventIndex = UInt8(eventString) else
        {
            throw GenericEventNodeError.unexpectedDecodedEventIndex
        }

        guard let module = runtimeMetadata.modules.first(where: { $0.index == eventModule }) else {
            throw GenericEventNodeError.unexpectedEventModule(value: UInt64(eventModule))
        }

        guard let event = try runtimeMetadata.getEvent(in: module, at: eventIndex) else {
            throw GenericEventNodeError.unexpectedEventIndex(value: UInt64(eventIndex))
        }

        let arguments = event.arguments

        let params: [JSON] = try arguments.map { try decoder.read(type: $0) }

        return .arrayValue([
            .unsignedIntValue(UInt64(eventModule)),
            .unsignedIntValue(UInt64(eventIndex)),
            .arrayValue(params),
        ])
    }
}
