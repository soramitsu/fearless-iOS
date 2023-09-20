import Foundation

enum NFTFetchingServiceError: Error {
    case emptyResponse
}

protocol NFTFetchingServiceProtocol {
    func fetchCollections(for wallet: MetaAccountModel) async throws -> [NFTCollection]
    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT]
    func fetchNftsHistory(for wallet: MetaAccountModel) async throws -> [NFTHistoryObject]
    func fetchNfts(for history: [NFTHistoryObject]) async throws -> [NFT]
}
