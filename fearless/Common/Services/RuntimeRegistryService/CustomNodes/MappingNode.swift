import Foundation
import FearlessUtils

struct NamedType {
    let name: String
    let type: String
}

struct MappingNode: Node {
    let typeName: String
    let typeMapping: [NamedType]

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let mapping = value.dictValue else {
            throw DynamicScaleEncoderError.dictExpected(json: value)
        }

        guard typeMapping.count == mapping.count else {
            let fieldNames = typeMapping.map { $0.name }
            throw DynamicScaleEncoderError.unexpectedStructFields(json: value,
                                                                  expectedFields: fieldNames)
        }

        for index in 0..<typeMapping.count {
            guard let child = mapping[typeMapping[index].name] else {
                throw DynamicScaleCoderError.unresolverType(name: typeMapping[index].name)
            }

            try encoder.append(json: child, type: typeMapping[index].type)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let dictJson = try typeMapping.reduce(into: [String: JSON]()) { (result, item) in
            let json = try decoder.read(type: item.type)
            result[item.name] = json
        }

        return .dictionaryValue(dictJson)
    }
}
