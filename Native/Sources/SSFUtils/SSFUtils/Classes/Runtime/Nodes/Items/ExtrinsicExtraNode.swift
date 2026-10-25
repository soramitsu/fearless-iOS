import Foundation

public enum ExtrinsicExtraNodeError: Error {
    case invalidParams
    case unsupportedMetadataHashMode
}

public class ExtrinsicExtraNode: Node {
    public var typeName: String { GenericType.extrinsicExtra.name }
    public let runtimeMetadata: RuntimeMetadata
    public var typeRegistry: TypeRegistryProtocol?

    public init(runtimeMetadata: RuntimeMetadata) {
        self.runtimeMetadata = runtimeMetadata
    }

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let params = value.dictValue else {
            throw DynamicScaleEncoderError.dictExpected(json: value)
        }

        for checkString in try runtimeMetadata.extrinsic
            .signedExtensions(using: runtimeMetadata.schemaResolver)
        {
            guard let check = ExtrinsicCheck.from(
                string: checkString,
                runtimeMetadata: runtimeMetadata
            ) else {
                continue
            }

            switch check {
            case .checkMetadataHash:
                try encoder.appendU8(json: .stringValue("0"))
            case .mortality:
                guard let era = params[ExtrinsicSignedExtra.CodingKeys.era.rawValue] else {
                    throw ExtrinsicExtraNodeError.invalidParams
                }

                try encoder.append(json: era, type: GenericType.era.name)
            case .nonce:
                guard let nonce = params[ExtrinsicSignedExtra.CodingKeys.nonce.rawValue] else {
                    throw ExtrinsicExtraNodeError.invalidParams
                }

                try encoder.appendCompact(json: nonce, type: KnownType.index.name)
            case .txPayment:
                guard let tip = params[ExtrinsicSignedExtra.CodingKeys.tip.rawValue] else {
                    throw ExtrinsicExtraNodeError.invalidParams
                }

                try encoder.appendCompact(json: tip, type: KnownType.balance.name)
            case .assetTxPayment: // yet exclusively Statemint/Statemint case
                guard let tip = params[ExtrinsicSignedExtra.CodingKeys.tip.rawValue] else {
                    throw ExtrinsicExtraNodeError.invalidParams
                }

                try encoder.appendCompact(json: tip, type: KnownType.balance.name)
                try encoder.appendOption(json: .null, type: PrimitiveType.u32.name)
                
            case .appCheck:
                guard let checkAppId = params[ExtrinsicSignedExtra.CodingKeys.appId.rawValue] else {
                    continue
                }
                
                try encoder.appendCompact(json: checkAppId, type: KnownType.balance.name)

            default:
                continue
            }
        }
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        let extra = try runtimeMetadata.extrinsic
            .signedExtensions(using: runtimeMetadata.schemaResolver)
            .reduce(into: [String: JSON]()) { result, item in
                guard let check = ExtrinsicCheck.from(string: item, runtimeMetadata: runtimeMetadata) else {
                    return
                }

                switch check {
                case .checkMetadataHash:
                    guard try decoder.readU8() == .stringValue("0") else {
                        throw ExtrinsicExtraNodeError.unsupportedMetadataHashMode
                    }
                case .mortality:
                    let era = try decoder.read(type: GenericType.era.rawValue)
                    result[ExtrinsicSignedExtra.CodingKeys.era.rawValue] = era
                case .nonce:
                    let nonce = try decoder.readCompact(type: KnownType.index.rawValue)
                    result[ExtrinsicSignedExtra.CodingKeys.nonce.rawValue] = nonce
                case .txPayment:
                    let tip = try decoder.readCompact(type: KnownType.balance.rawValue)
                    result[ExtrinsicSignedExtra.CodingKeys.tip.rawValue] = tip
                default:
                    return
                }
            }

        return .dictionaryValue(extra)
    }
}
