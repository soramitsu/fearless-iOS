import Foundation
import SSFModels

struct NftAttribute: Codable, Equatable, Hashable {
    let value: String
    let key: String
}

struct NFT: Codable, Equatable, Hashable {
    let chain: ChainModel
    let tokenId: String
    let title: String?
    let description: String?
    let smartContract: String
    let metadata: NFTMetadata?
    let mediaThumbnail: String?
    let media: [NFTMedia]?
    let tokenType: String?
    let attributes: [NftAttribute]?
    let collectionName: String?
    let collection: NFTCollection?
}

struct NFTMetadata: Codable, Equatable, Hashable {
    let name: String?
    let description: String?
    let image: String?

    var imageURL: URL? {
        guard let image = image, let url = URL(string: image) else {
            return nil
        }

        return url.normalizedIpfsURL
    }
}

struct NFTMedia: Codable, Equatable, Hashable {
    let thumbnail: String?
    let mediaPath: String?
    let format: String?

    var normalizedURL: URL? {
        guard let mediaPath = mediaPath, let url = URL(string: mediaPath) else {
            return nil
        }

        return url.normalizedIpfsURL
    }
}

struct NFTCollection: Codable, Equatable, Hashable {
    let address: String?
    let numberOfTokens: UInt32?
    let isSpam: Bool?
    let title: String?
    let name: String?
    let creator: String?
    let price: Float?
    let media: [NFTMedia]?
    let tokenType: String?
    let desc: String?
    let opensea: AlchemyNftOpenseaInfo?
    let chain: ChainModel

    var nfts: [NFT]?
}
