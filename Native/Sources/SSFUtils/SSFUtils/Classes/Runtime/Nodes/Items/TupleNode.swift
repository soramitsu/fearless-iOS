import Foundation

public class TupleNode: Node {
    public let typeName: String
    public let innerNodes: [Node]

    public init(typeName: String, innerNodes: [Node]) {
        self.typeName = typeName
        self.innerNodes = innerNodes
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        var components: [JSON]? = value.arrayValue
        if components == nil {
            if let dictValue = value.dictValue {
                if dictValue.count == innerNodes.count {
                    // Accept eligible size of dictionary as array of values
                    components = dictValue.values.map { $0 }
                }
            } else if innerNodes.count == 1 {
                // accept single value JSON if tuple fields count is the 1 (backward compatibility
                // for <= V13 for some types)
                switch value {
                case .unsignedIntValue, .signedIntValue, .stringValue, .boolValue, .null:
                    components = [value]
                default:
                    break
                }
            }
        }

        guard let components = components else {
            throw DynamicScaleEncoderError.unexpectedTupleJSON(json: value)
        }

        guard components.count == innerNodes.count else {
            throw DynamicScaleEncoderError.unexpectedTupleComponents(
                count: components.count,
                actual: innerNodes.count
            )
        }

        for index in 0 ..< innerNodes.count {
            try encoder.append(json: components[index], type: innerNodes[index].typeName)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let jsons = try innerNodes.reduce([JSON]()) { result, item in
            let json = try decoder.read(type: item.typeName)
            return result + [json]
        }

        return .arrayValue(jsons)
    }
}
