import BigInt
import Foundation

public enum ExtrinsicNodeError: Error {
    case invalidParams
    case invalidVersion
}

public class ExtrinsicNode: Node {
    public var typeName: String { GenericType.extrinsic.name }

    public init() {}

    public func accept(encoder: DynamicScaleEncoding, value: JSON) throws {
        guard let params = value.dictValue else {
            throw DynamicScaleEncoderError.dictExpected(json: value)
        }

        guard let call = params[Extrinsic.CodingKeys.call.rawValue] else {
            throw ExtrinsicNodeError.invalidParams
        }

        let subEncoder = encoder.newEncoder()

        if let signature = params[Extrinsic.CodingKeys.signature.rawValue], signature != .null {
            let version: UInt8 = ExtrinsicConstants.version | ExtrinsicConstants.signedMask
            try subEncoder.append(encodable: version)

            try subEncoder.append(json: signature, type: GenericType.extrinsicSignature.name)
        } else {
            try subEncoder.append(encodable: ExtrinsicConstants.version)
        }

        try subEncoder.append(json: call, type: KnownType.call.name)

        let encoded = try subEncoder.encode()

        try encoder.append(encodable: encoded)
    }

    public func accept(decoder: DynamicScaleDecoding) throws -> JSON {
        // read and ignore extrinsic length
        let _: BigUInt = try decoder.read()
        let version: UInt8 = try decoder.read()

        let isSigned = (version & ExtrinsicConstants.signedMask) != 0

        if (version & (~ExtrinsicConstants.signedMask)) != ExtrinsicConstants.version {
            throw ExtrinsicNodeError.invalidVersion
        }

        var result: [String: JSON] = [:]

        if isSigned {
            let signature = try decoder.read(type: GenericType.extrinsicSignature.name)
            result[Extrinsic.CodingKeys.signature.rawValue] = signature
        }

        let call = try decoder.read(type: KnownType.call.name)
        result[Extrinsic.CodingKeys.call.rawValue] = call

        return .dictionaryValue(result)
    }
}
