import Foundation

public class StructNode: Node {
    public let typeName: String
    public let typeMapping: [NameNode]

    public init(typeName: String, typeMapping: [NameNode]) {
        self.typeName = typeName
        self.typeMapping = typeMapping
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        var mapping: [String: JSON]? = value.dictValue
        if mapping == nil {
            if let arrayValue = value.arrayValue {
                if arrayValue.count == typeMapping.count {
                    // Accept eligible size of array as array of values
                    mapping = [:]
                    for (i, value) in arrayValue.enumerated() {
                        let typeName = typeMapping[i].name
                        mapping?[typeName] = value
                    }
                }
            } else if typeMapping.count == 1 {
                // accept single value JSON if struct fields count is the 1 (backward compatibility
                // for <= V13 for some types)
                switch value {
                case .unsignedIntValue, .signedIntValue, .stringValue, .boolValue, .null:
                    let typeName = typeMapping[0].name
                    mapping = [typeName: value]
                default:
                    break
                }
            }
        }

        guard let mapping = mapping else {
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

            try encoder.append(json: child, type: typeMapping[index].node.typeName)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let dictJson = try typeMapping.reduce(into: [String: JSON]()) { result, item in
            let json = try decoder.read(type: item.node.typeName)
            result[item.name] = json
        }

        return .dictionaryValue(dictJson)
    }
}
