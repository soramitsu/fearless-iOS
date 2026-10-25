import Foundation

public class SessionKeysSubstrateNode: Node {
    static let fieldNames: [String] = ["grandpa", "babe", "im_online"]
    static let fieldTypeName: String = GenericType.accountId.name

    public var typeName: String { GenericType.sessionKeys.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let fieldValues = value.arrayValue else {
            throw DynamicScaleEncoderError.arrayExpected(json: value)
        }

        guard Self.fieldNames.count == fieldValues.count else {
            throw DynamicScaleEncoderError.unexpectedStructFields(
                json: value,
                expectedFields: Self.fieldNames
            )
        }

        for index in 0 ..< Self.fieldNames.count {
            try encoder.append(json: fieldValues[index], type: Self.fieldTypeName)
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let jsons = try Self.fieldNames.reduce([JSON]()) { result, _ in
            let json = try decoder.read(type: Self.fieldTypeName)
            return result + [json]
        }

        return .arrayValue(jsons)
    }
}
