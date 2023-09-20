import Foundation

struct AlchemyNftSpamInfo: Decodable {
    let isSpam: String?
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
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case media
        case id
        case balance
        case contract
        case metadata
        case spamInfo
        case contractMetadata
    }

    let title: String
    let description: String?
    let media: [AlchemyNftMediaInfo]?
    let id: AlchemyNftId
    let balance: String?
    let contract: AlchemyNftContractInfo?
    let metadata: AlchemyNftMetadata?
    let spamInfo: AlchemyNftSpamInfo?
    let contractMetadata: AlchemyNftCollection?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        id = try container.decode(AlchemyNftId.self, forKey: .id)

        description = try? container.decode(String.self, forKey: .description)
        media = try? container.decode([AlchemyNftMediaInfo]?.self, forKey: .media)
        balance = try? container.decode(String.self, forKey: .balance)
        contract = try? container.decode(AlchemyNftContractInfo.self, forKey: .contract)
        metadata = try? container.decode(AlchemyNftMetadata.self, forKey: .metadata)
        spamInfo = try? container.decode(AlchemyNftSpamInfo.self, forKey: .spamInfo)
        contractMetadata = try? container.decode(AlchemyNftCollection.self, forKey: .contractMetadata)
    }
}

struct AlchemyNftsResponse: Decodable {
    let ownedNfts: [AlchemyNftInfo]?
}
