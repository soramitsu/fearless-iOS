import Foundation

struct AlchemyNftSpamInfo: Decodable {
    let isSpam: Bool?
    let classifications: [String]?
}

struct AlchemyNftContractInfo: Decodable {
    let address: String
}

struct AlchemyNftTokenMetadata: Decodable {
    let tokenType: String
}

struct AlchemyNftId: Decodable {
    let tokenId: String
    let tokenMetadata: AlchemyNftTokenMetadata?
}

struct AlchemyNftAttribute: Decodable {
    let value: String
    let traitType: String
}

struct AlchemyNftMetadata: Decodable {
    let name: String?
    let description: String?
//    let attributes: [AlchemyNftAttribute]?
    let backgroundColor: String?
    let poster: String?
}

struct AlchemyNftInfo: Decodable {
    let title: String
    let description: String?
    let media: [AlchemyNftMediaInfo]?
    let id: AlchemyNftId
    let balance: String?
    let contract: AlchemyNftContractInfo
    let metadata: AlchemyNftMetadata?
    let spamInfo: AlchemyNftSpamInfo?
    let contractMetadata: AlchemyNftCollection?
}

struct AlchemyNftsResponse: Decodable {
    let ownedNfts: [AlchemyNftInfo]?
}
