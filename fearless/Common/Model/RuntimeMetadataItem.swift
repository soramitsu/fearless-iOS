import Foundation
import RobinHood
import FearlessUtils

struct RuntimeMetadataItem: Codable & Equatable {
    let chain: String
    let version: UInt32
    let txVersion: UInt32
    let metadata: Data
    let resolver: Schema.Resolver?

    enum CodingKeys: String, CodingKey {
        case chain
        case version
        case txVersion
        case metadata
        case resolver
    }

    init(
        chain: String,
        version: UInt32,
        txVersion: UInt32,
        metadata: Data,
        resolver: Schema.Resolver?
    ) {
        self.chain = chain
        self.version = version
        self.txVersion = txVersion
        self.metadata = metadata
        self.resolver = resolver
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        chain = try container.decode(String.self, forKey: .chain)
        version = try container.decode(UInt32.self, forKey: .version)
        txVersion = try container.decode(UInt32.self, forKey: .txVersion)
        metadata = try container.decode(Data.self, forKey: .metadata)
        resolver = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(chain, forKey: .chain)
        try container.encode(version, forKey: .version)
        try container.encode(txVersion, forKey: .txVersion)
        try container.encode(metadata, forKey: .metadata)
    }
}

extension RuntimeMetadataItem: Identifiable {
    var identifier: String { chain }
}
