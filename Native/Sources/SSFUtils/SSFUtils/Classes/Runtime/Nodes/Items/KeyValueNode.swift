import Foundation

public class KeyValueNode: Node {
    public let typeName: String

    public init(typeName: String) {
        self.typeName = typeName
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let mapping = value.dictValue else {
            throw DynamicScaleEncoderError.dictExpected(json: value)
        }

        let tuples: [ScaleTuple<String, String>] = try mapping.enumerated().map { _, element in
            guard let value = element.value.stringValue else {
                throw DynamicScaleEncoderError.stringExpected(json: element.value)
            }

            return ScaleTuple(first: element.key, second: value)
        }

        try encoder.append(encodable: tuples)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let tuples: [ScaleTuple<String, String>] = try decoder.read()

        let mapping = tuples.reduce(into: [String: JSON]()) { result, item in
            result[item.first] = .stringValue(item.second)
        }

        return .dictionaryValue(mapping)
    }
}
