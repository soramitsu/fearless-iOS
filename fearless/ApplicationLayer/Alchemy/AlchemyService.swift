import Foundation
import SSFUtils
import BigInt

final class AlchemyService {
    func fetchTransactionHistory(request: AlchemyHistoryRequest) async throws -> AlchemyResponse<AlchemyHistory> {
        let body = JSONRPCInfo(identifier: 1, jsonrpc: "2.0", method: AlchemyEndpoint.getAssetTransfers.rawValue, params: [request])
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorker()
        let response: AlchemyResponse<AlchemyHistory> = try await worker.performRequest(with: request)
        return response
    }
}
