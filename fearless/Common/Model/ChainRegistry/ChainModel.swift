import Foundation

struct ChainModel: Codable {
    typealias Id = Data

    let chainId: Id
    let assets: [AssetModel]
    let nodes: [ChainNodeModel]
    let prefix: UInt16
    let preferredUrl: URL?
    let isEthereum: Bool
}
