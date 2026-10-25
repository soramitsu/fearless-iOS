import Foundation
import SSFModels

// MARK: - RemoteAssetMultilocation

struct RemoteAssetMultilocation: Codable, Equatable {
    let name: String
    let chainId: String
    let assets: [AssetMultilocation]
}

// MARK: - Asset

struct AssetMultilocation: Codable, Equatable {
    let id: String
    let symbol: String
    /// Number of parent hops of the asset's location, when the config states it. A config without
    /// it leaves the call factory to derive it from `interiors`.
    let parents: UInt8?
    let interiors: [XcmJunction]

    init(id: String, symbol: String, parents: UInt8? = nil, interiors: [XcmJunction]) {
        self.id = id
        self.symbol = symbol
        self.parents = parents
        self.interiors = interiors
    }
}
