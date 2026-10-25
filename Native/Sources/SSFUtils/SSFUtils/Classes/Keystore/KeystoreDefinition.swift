import Foundation

public struct KeystoreDefinition: Codable {
    public let address: String?
    public let encoded: String
    public let encoding: KeystoreEncoding
    public let meta: KeystoreMeta?

    public init(
        address: String?,
        encoded: String,
        encoding: KeystoreEncoding,
        meta: KeystoreMeta?
    ) {
        self.address = address
        self.encoded = encoded
        self.encoding = encoding
        self.meta = meta
    }
}

public struct KeystoreEncoding: Codable {
    public let content: [String]
    public let type: [String]
    public let version: String

    public init(content: [String], type: [String], version: String) {
        self.content = content
        self.type = type
        self.version = version
    }

    public init(from decoder: Decoder) throws {
        let data = try decoder.container(keyedBy: CodingKeys.self)
        content = try data.decode([String].self, forKey: .content)
        type = try data.decode([String].self, forKey: .type)
        if let stringVersion = try? data.decode(String.self, forKey: .version) {
            version = stringVersion
        } else if let numberVersion = try? data.decode(Int.self, forKey: .version) {
            version = String(numberVersion)
        } else {
            throw DecodingError.typeMismatch(
                Self.self,
                .init(
                    codingPath: data.codingPath,
                    debugDescription: "Unexpected keystore encoding type",
                    underlyingError: nil
                )
            )
        }
    }
}

public struct KeystoreMeta: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case createdAt = "whenCreated"
        case genesisHash
        case isHardware
        case tags
    }

    public let name: String?
    public let createdAt: Int64?
    public let genesisHash: String?
    public let isHardware: Bool?
    public let tags: [String]?
}
