import Foundation
import BigInt

struct AlchemyNftCollectionsResponse: Decodable {
    let contracts: [AlchemyNftCollection]?
    let totalCount: UInt32
}

struct AlchemyNftCollection: Decodable {
    let address: String?
    let totalBalance: UInt32?
    let numDistinctTokensOwned: UInt32?
    let isSpam: String?
    let tokenId: String?
    let name: String?
    let title: String?
    let symbol: String?
    let totalSupply: String?
    let tokenType: String?
    let contractDeployer: String?
    let deployedBlockNumber: UInt64?
    let openSea: AlchemyNftOpenseaInfo?
    let media: [AlchemyNftMediaInfo]?
}
