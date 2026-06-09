import Foundation
import SSFUtils
import BigInt
import SSFNetwork

final class AlchemyService {
    private let networkWorker: NetworkWorkerDefault
    private let apiKeySource: AlchemyAPIKeySource

    init(
        networkWorker: NetworkWorkerDefault = NetworkWorkerDefault(),
        apiKeySource: AlchemyAPIKeySource = AlchemyEnvironmentAPIKeySource()
    ) {
        self.networkWorker = networkWorker
        self.apiKeySource = apiKeySource
    }

    func fetchTransactionHistory(request: AlchemyHistoryRequest) async throws -> AlchemyResponse<AlchemyHistory> {
        let body = JSONRPCInfo(identifier: 1, jsonrpc: "2.0", method: AlchemyEndpoint.getAssetTransfers.rawValue, params: [request])
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded, apiKeySource: apiKeySource)
        let response: AlchemyResponse<AlchemyHistory> = try await networkWorker.performRequest(with: request)
        return response
    }
}
