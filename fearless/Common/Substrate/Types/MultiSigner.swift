import Foundation

enum MultiSigner: Equatable {
    static let ed25519Field = "Ed25519"
    static let sr25519Field = "Sr25519"
    static let ecdsaField = "Ecdsa"

    case ed25519(_ data: Data)
    case sr25519(_ data: Data)
    case ecdsa(_ data: Data)
}

extension MultiSigner: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let type = try container.decode(String.self)
        let bytes = try container.decode([StringScaleMapper<UInt8>].self).map(\.value)
        let data = Data(bytes)

        switch type {
        case Self.ed25519Field:
            self = .ed25519(data)
        case Self.sr25519Field:
            self = .sr25519(data)
        case Self.ecdsaField:
            self = .ecdsa(data)
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()

        let data: Data

        switch self {
        case let .ed25519(value):
            try container.encode(Self.ed25519Field)
            data = value
        case let .sr25519(value):
            try container.encode(Self.sr25519Field)
            data = value
        case let .ecdsa(value):
            try container.encode(Self.ecdsaField)
            data = value
        }

        let encodingList = data.map { StringScaleMapper(value: $0) }
        try container.encode(encodingList)
    }
}
