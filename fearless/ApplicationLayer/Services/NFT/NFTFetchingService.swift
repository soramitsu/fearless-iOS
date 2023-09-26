import Foundation

enum NFTFetchingServiceError: Error {
    case emptyResponse
}

protocol NFTFetchingServiceProtocol {
    func fetchCollections(for wallet: MetaAccountModel) async throws -> [NFTCollection]
    func fetchNfts(for wallet: MetaAccountModel) async throws -> [NFT]
}
