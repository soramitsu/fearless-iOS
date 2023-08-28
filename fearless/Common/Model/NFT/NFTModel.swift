import Foundation
import SSFModels

struct NFT: Codable, Equatable, Hashable {
    let chain: ChainModel
    let tokenId: String
    let tokenName: String
    let smartContract: String
    let metadata: NFTMetadata?
}

struct NFTMetadata: Codable, Equatable, Hashable {
    let name: String?
    let description: String?
    let image: String?
}

struct NFTCollection: Codable, Equatable, Hashable {
    let chain: String
    let name: String
    let image: String?
    let desc: String?
    let nfts: [NFT]
}
