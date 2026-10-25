import Foundation

public class EnumNode: Node {
    public let typeName: String
    public let typeMapping: [NameNode]

    public init(typeName: String, typeMapping: [NameNode]) {
        self.typeName = typeName
        self.typeMapping = typeMapping
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let enumValue = value.arrayValue,
              enumValue.count == 2,
              let caseValue = enumValue.first?.stringValue,
              let assocValue = enumValue.last else
        {
            throw DynamicScaleEncoderError.unexpectedEnumJSON(json: value)
        }

        guard let type = typeMapping
            .first(where: { $0.name.lowercased() == caseValue.lowercased() }) else
        {
            throw DynamicScaleEncoderError.unexpectedEnumCase(value: caseValue)
        }

        try encoder.append(encodable: type.index)

        guard assocValue != JSON.null else {
            return
        }

        try encoder.append(json: assocValue, type: type.node.typeName)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        guard let caseValueStr = try decoder.readU8().stringValue,
              let caseIndex = UInt8(caseValueStr) else
        {
            throw DynamicScaleDecoderError.unexpectedEnumCase
        }

        guard let type = typeMapping.first(where: { $0.index == caseIndex }) else {
            throw DynamicScaleDecoderError.invalidEnumCase(index: caseIndex)
        }

        let json = try decoder.read(type: type.node.typeName)

        return .arrayValue([.stringValue(type.name), json])
    }
}
