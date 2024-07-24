import Foundation
import SSFNetwork

enum NomisAccountStatisticsFetcherError: Error {
    case badBaseURL
}

final class NomisAccountStatisticsFetcher {
    private let networkWorker: NetworkWorker
    private let signer: RequestSigner

    init(
        networkWorker: NetworkWorker,
        signer: RequestSigner
    ) {
        self.networkWorker = networkWorker
        self.signer = signer
    }
}

extension NomisAccountStatisticsFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String,
        cacheOptions: CachedNetworkRequestTrigger
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<AccountStatisticsResponse>, Error> {
        guard let baseURL = URL(string: "https://api.nomis.cc/api/v1/multichain-score/wallet/") else {
            throw NomisAccountStatisticsFetcherError.badBaseURL
        }

        let request = try NomisAccountStatisticsRequest(
            baseURL: baseURL,
            address: address,
            endpoint: "score"
        )
        request.signingType = .custom(signer: signer)
        request.decoderType = .codable(jsonDecoder: NomisJSONDecoder())
        return await networkWorker.performRequest(with: request, withCacheOptions: cacheOptions)
    }

    func fetchStatistics(address: String) async throws -> AccountStatisticsResponse? {
        guard let baseURL = URL(string: "https://api.nomis.cc/api/v1/multichain-score/wallet/") else {
            throw NomisAccountStatisticsFetcherError.badBaseURL
        }

        let request = try NomisAccountStatisticsRequest(
            baseURL: baseURL,
            address: address,
            endpoint: "score"
        )
        request.signingType = .custom(signer: signer)
        request.decoderType = .codable(jsonDecoder: NomisJSONDecoder())
        return try await networkWorker.performRequest(with: request)
    }
}
