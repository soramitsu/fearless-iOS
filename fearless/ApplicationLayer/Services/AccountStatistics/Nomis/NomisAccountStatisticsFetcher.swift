import Foundation
import SSFNetwork

enum NomisAccountStatisticsFetcherError: Error {
    case badBaseURL
}

final class NomisAccountStatisticsFetcher {
    private let updateIntervalInSeconds: TimeInterval = 60 * 60 * 6 // Every 6 hours
    private let networkWorker: NetworkWorker
    private let signer: RequestSigner
    private let cache: AccountStatisticsCache

    init(
        networkWorker: NetworkWorker,
        signer: RequestSigner,
        cache: AccountStatisticsCache
    ) {
        self.networkWorker = networkWorker
        self.signer = signer
        self.cache = cache
    }
    
    private func shouldUpdate(for address: String) -> Bool {
        let lastUpdate = cache.lastUpdate(for: address)

        guard let lastUpdate else {
            return true
        }
        
        return abs(lastUpdate.timeIntervalSinceNow) > updateIntervalInSeconds
    }
}

extension NomisAccountStatisticsFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<AccountStatisticsResponse>, Error> {
        let request = try NomisAccountStatisticsRequest(
            baseURL: ApplicationConfig.shared.nomisAccountScoreURL,
            address: address,
            endpoint: "score"
        )
        request.signingType = .custom(signer: signer)
        request.decoderType = .codable(jsonDecoder: NomisJSONDecoder())
        
        let shouldUpdate = shouldUpdate(for: address)
        let cacheOptions: CachedNetworkRequestTrigger = shouldUpdate ? .onAll : .onCache
        
        if shouldUpdate {
            cache.setLastUpdate(for: address)
        }

        return await networkWorker.performRequest(with: request, withCacheOptions: cacheOptions)
    }

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse? {
        let request = try NomisAccountStatisticsRequest(
            baseURL: ApplicationConfig.shared.nomisAccountScoreURL,
            address: address,
            endpoint: "score"
        )
        request.signingType = .custom(signer: signer)
        request.decoderType = .codable(jsonDecoder: NomisJSONDecoder())
        return try await networkWorker.performRequest(with: request)
    }
}
