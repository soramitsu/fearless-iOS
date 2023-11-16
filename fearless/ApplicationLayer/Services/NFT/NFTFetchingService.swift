import Foundation
import SSFModels

enum NFTFetchingServiceError: Error {
    case emptyResponse
}

protocol NFTFetchingServiceProtocol {
    func fetchCollections(for wallet: MetaAccountModel) async throws -> [NFTCollection]
    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT]
    func fetchCollectionNfts(collectionAddress: String, chain: ChainModel) async throws -> [NFT]
}
