import Foundation
import SSFModels
import SSFUtils

struct AccountId32Value: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case network
        case accountId = "id"
    }

    let network: XcmJunctionNetworkId?
    @BytesCodable var accountId: AccountId

    init(network: XcmJunctionNetworkId?, accountId: AccountId) {
        self.network = network
        _accountId = BytesCodable(wrappedValue: accountId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNetwork(network, forKey: .network)
        try container.encode(_accountId, forKey: .accountId)
    }
}

struct AccountId20Value: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case network
        case key
    }

    let network: XcmJunctionNetworkId?
    @BytesCodable var key: AccountId

    init(network: XcmJunctionNetworkId?, key: AccountId) {
        self.network = network
        _key = BytesCodable(wrappedValue: key)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNetwork(network, forKey: .network)
        try container.encode(_key, forKey: .key)
    }
}

struct AccountIndexValue: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case network
        case index
    }

    let network: XcmJunctionNetworkId?
    @StringCodable var index: UInt64

    init(network: XcmJunctionNetworkId?, index: UInt64) {
        self.network = network
        _index = StringCodable(wrappedValue: index)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeNetwork(network, forKey: .network)
        try container.encode(_index, forKey: .index)
    }
}

private extension KeyedEncodingContainer {
    /// `Option<NetworkId>` needs an explicit `null` for `None`; a missing key is not a value.
    mutating func encodeNetwork(_ network: XcmJunctionNetworkId?, forKey key: Key) throws {
        if let network {
            try encode(network, forKey: key)
        } else {
            try encodeNil(forKey: key)
        }
    }
}
