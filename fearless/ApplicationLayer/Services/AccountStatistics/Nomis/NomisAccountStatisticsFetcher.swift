import Foundation
import SSFNetwork

enum NomisAccountStatisticsFetcherError: Error {
    case badBaseURL
}

final class NomisAccountStatisticsFetcher {
    private let networkWorker: NetworkWorkerDefault
    private let signer: RequestSigner

    init(
        networkWorker: NetworkWorkerDefault,
        signer: RequestSigner
    ) {
        self.networkWorker = networkWorker
        self.signer = signer
    }
}

extension NomisAccountStatisticsFetcher: AccountStatisticsFetching {
    func subscribeForStatistics(
        address: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        let request = try NomisAccountStatisticsRequest(
            baseURL: ApplicationConfig.shared.nomisAccountScoreURL,
            address: address,
            endpoint: "score"
        )
        request.signingType = .custom(signer: signer)
        request.decoderType = .codable(jsonDecoder: NomisJSONDecoder())
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let value: AccountStatisticsResponse = try await networkWorker.performRequest(with: request)
                    continuation.yield(value)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
