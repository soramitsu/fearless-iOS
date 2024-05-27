import Foundation
import SSFModels

enum NFTFetchingServiceError: Error {
    case emptyResponse
}

protocol NFTFetchingServiceProtocol {
    func fetchCollections(
        for wallet: MetaAccountModel,
        excludeFilters: [NftCollectionFilter],
        chains: [ChainModel]?
    ) async throws -> [NFTCollection]

    func fetchNfts(
        for wallet: MetaAccountModel,
        excludeFilters: [NftCollectionFilter],
        chains: [ChainModel]?
    ) async throws -> [NFT]

    func fetchCollectionNfts(
        collectionAddress: String,
        chain: ChainModel,
        nextId: String?
    ) async throws -> NFTBatch

    func fetchOwners(
        for address: String,
        tokenId: String,
        chain: ChainModel
    ) async throws -> [String]
}
