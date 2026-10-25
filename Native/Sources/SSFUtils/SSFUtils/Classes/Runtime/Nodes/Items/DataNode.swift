import Foundation

public class DataNode: Node {
    public var typeName: String { GenericType.data.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let values = value.arrayValue, !values.isEmpty else {
            throw DynamicScaleEncoderError.arrayExpected(json: value)
        }

        guard let type = values[0].unsignedIntValue else {
            throw DynamicScaleEncoderError.unsignedIntExpected(json: values[0])
        }

        if type == 0 {
            return try encoder.append(encodable: ChainData.none)
        } else {
            guard values.count == 2,
                  let params = value[1]?.arrayValue,
                  params.count == 1,
                  let hex = params[0].stringValue else
            {
                throw DynamicScaleEncoderError.unexpectedEnumJSON(json: value)
            }

            let rawData = try Data(hexStringSSF: hex)

            switch type {
            case 1:
                try encoder.append(encodable: ChainData.raw(data: rawData))
            case 2:
                let hash = H256(value: rawData)
                try encoder.append(encodable: ChainData.blakeTwo256(data: hash))
            case 3:
                let hash = H256(value: rawData)
                try encoder.append(encodable: ChainData.sha256(data: hash))
            case 4:
                let hash = H256(value: rawData)
                try encoder.append(encodable: ChainData.keccak256(data: hash))
            case 5:
                let hash = H256(value: rawData)
                try encoder.append(encodable: ChainData.shaThree256(data: hash))
            default:
                throw DynamicScaleEncoderError.unsignedIntExpected(json: values[0])
            }
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let chainData: ChainData = try decoder.read()

        switch chainData {
        case .none:
            return .arrayValue([.unsignedIntValue(0)])
        case let .raw(data):
            let hex = data.toHex(includePrefix: true)
            return .arrayValue([.unsignedIntValue(1), .arrayValue([.stringValue(hex)])])
        case let .blakeTwo256(hash):
            let hex = hash.value.toHex(includePrefix: true)
            return .arrayValue([.unsignedIntValue(2), .arrayValue([.stringValue(hex)])])
        case let .sha256(hash):
            let hex = hash.value.toHex(includePrefix: true)
            return .arrayValue([.unsignedIntValue(3), .arrayValue([.stringValue(hex)])])
        case let .keccak256(hash):
            let hex = hash.value.toHex(includePrefix: true)
            return .arrayValue([.unsignedIntValue(4), .arrayValue([.stringValue(hex)])])
        case let .shaThree256(hash):
            let hex = hash.value.toHex(includePrefix: true)
            return .arrayValue([.unsignedIntValue(5), .arrayValue([.stringValue(hex)])])
        }
    }
}
