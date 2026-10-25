import Foundation

public class EnumValuesNode: Node {
    public let typeName: String
    public let values: [String]

    public init(typeName: String, values: [String]) {
        self.typeName = typeName
        self.values = values
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let caseValue = value.unsignedIntValue else {
            throw DynamicScaleEncoderError.unexpectedEnumJSON(json: value)
        }

        guard caseValue < values.count else {
            throw DynamicScaleEncoderError.unexpectedEnumValues(
                value: caseValue,
                count: values.count
            )
        }

        try encoder.appendU8(json: .stringValue(String(caseValue)))
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let caseValueStr = try decoder.readU8().stringValue,
              let caseValue = Int(caseValueStr) else
        {
            throw DynamicScaleDecoderError.unexpectedEnumCase
        }

        return .unsignedIntValue(UInt64(caseValue))
    }
}
