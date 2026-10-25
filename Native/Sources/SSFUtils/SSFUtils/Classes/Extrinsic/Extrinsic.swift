import BigInt
import Foundation

public enum ExtrinsicConstants {
    static let version: UInt8 = 4
    static let signedMask: UInt8 = 1 << 7
}

public struct ExtrinsicSignedExtra: Codable {
    enum CodingKeys: String, CodingKey {
        case era
        case nonce
        case tip
        case appId = "app_id"
    }

    public var era: Era?
    @OptionStringCodable public var nonce: UInt32?
    @OptionStringCodable public var tip: BigUInt?
    @OptionStringCodable public  var appId: BigUInt?

    public init(era: Era?, nonce: UInt32?, tip: BigUInt?, appId: BigUInt?) {
        self.era = era
        self.nonce = nonce
        self.tip = tip
        self.appId = appId
    }
}

public struct Extrinsic: Codable {
    enum CodingKeys: String, CodingKey {
        case call
        case signature
    }

    public let call: JSON
    public let signature: ExtrinsicSignature?

    public init(call: JSON, signature: ExtrinsicSignature?) {
        self.call = call
        self.signature = signature
    }
}

public struct ExtrinsicSignature: Codable {
    enum CodingKeys: String, CodingKey {
        case address
        case signature
        case extra
        case type
    }

    public let address: JSON
    public let signature: JSON
    public let extra: ExtrinsicSignedExtra
    public let type: String

    public init(address: JSON, signature: JSON, extra: ExtrinsicSignedExtra, type: String) {
        self.address = address
        self.signature = signature
        self.extra = extra
        self.type = type
    }
}

enum MultiSignatureError: Error {
    case unexpectedType
}

public enum MultiSignature: Codable {
    static let sr25519Field = "Sr25519"
    static let ed25519Field = "Ed25519"
    static let ecdsaField = "Ecdsa"

    case sr25519(data: Data)
    case ed25519(data: Data)
    case ecdsa(data: Data)

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)
        let data = try container.decode(Data.self)

        switch type {
        case Self.sr25519Field:
            self = .sr25519(data: data)
        case Self.ed25519Field:
            self = .ed25519(data: data)
        case Self.ecdsaField:
            self = .ecdsa(data: data)
        default:
            throw MultiSignatureError.unexpectedType
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .sr25519(data):
            try container.encode(Self.sr25519Field)
            try container.encode(data)
        case let .ed25519(data):
            try container.encode(Self.ed25519Field)
            try container.encode(data)
        case let .ecdsa(data):
            try container.encode(Self.ecdsaField)
            try container.encode(data)
        }
    }
}
