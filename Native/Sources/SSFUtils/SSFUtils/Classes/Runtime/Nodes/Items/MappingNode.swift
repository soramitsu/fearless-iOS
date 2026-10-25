import Foundation

public struct NamedType {
    public let name: String
    public let type: String

    public init(name: String, type: String) {
        self.name = name
        self.type = type
    }
}

public class MappingNode: Node {
    public let typeName: String
    public let typeMapping: [NamedType]

    public init(typeName: String, typeMapping: [NamedType]) {
        self.typeName = typeName
        self.typeMapping = typeMapping
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let mapping = value.dictValue else {
            throw DynamicScaleEncoderError.dictExpected(json: value)
        }

        guard typeMapping.count == mapping.count else {
            let fieldNames = typeMapping.map { $0.name }
            throw DynamicScaleEncoderError.unexpectedStructFields(
                json: value,
                expectedFields: fieldNames
            )
        }

        for index in 0 ..< typeMapping.count {
            guard let child = mapping[typeMapping[index].name] else {
                throw DynamicScaleCoderError.unresolvedType(name: typeMapping[index].name)
            }

            try encoder.append(json: child, type: typeMapping[index].type)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let dictJson = try typeMapping.reduce(into: [String: JSON]()) { result, item in
            let json = try decoder.read(type: item.type)
            result[item.name] = json
        }

        return .dictionaryValue(dictJson)
    }
}
