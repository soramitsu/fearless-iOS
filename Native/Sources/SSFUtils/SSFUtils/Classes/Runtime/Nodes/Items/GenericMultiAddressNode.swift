import Foundation

public class GenericMultiAddressNode: Node {
    public static let typeMapping = [
        [MultiAddress.accountIdField, GenericType.accountId.name],
        [MultiAddress.indexField, "Compact<\(GenericType.accountIndex.name)>"],
        [MultiAddress.rawField, GenericType.bytes.name],
        [MultiAddress.address32Field, GenericType.h256.name],
        [MultiAddress.address20Field, GenericType.h160.name],
    ]

    public var typeName: String { GenericType.multiAddress.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let enumValue = value.arrayValue,
              enumValue.count == 2,
              let caseValue = enumValue.first?.stringValue,
              let assocValue = enumValue.last else
        {
            throw DynamicScaleEncoderError.unexpectedEnumJSON(json: value)
        }

        guard let index = Self.typeMapping.firstIndex(where: { $0[0] == caseValue }) else {
            throw DynamicScaleEncoderError.unexpectedEnumCase(value: caseValue)
        }

        try encoder.appendU8(json: .stringValue(String(index)))
        try encoder.append(json: assocValue, type: Self.typeMapping[index][1])
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let caseValueStr = try decoder.readU8().stringValue,
              let caseValue = Int(caseValueStr) else
        {
            throw DynamicScaleDecoderError.unexpectedEnumCase
        }

        guard caseValue < Self.typeMapping.count else {
            throw DynamicScaleDecoderError.invalidCustomEnumCase(
                value: caseValue,
                count: Self.typeMapping.count
            )
        }

        let json = try decoder.read(type: Self.typeMapping[caseValue][1])

        return .arrayValue([.stringValue(Self.typeMapping[caseValue][0]), json])
    }
}
