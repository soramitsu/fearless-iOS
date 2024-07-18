import Foundation
import SSFUtils
import BigInt
import SSFNetwork

struct EthereumBalanceRequestParams: Encodable {
    let address: String
    let smartContracts: [String]

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(address)
        try container.encode(smartContracts)
    }
}

final class AlchemyService {
    func fetchTransactionHistory(request: AlchemyHistoryRequest) async throws -> AlchemyResponse<AlchemyHistory> {
        let body = JSONRPCInfo(identifier: 1, jsonrpc: "2.0", method: AlchemyEndpoint.getAssetTransfers.rawValue, params: [request])
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorkerImpl()
        let response: AlchemyResponse<AlchemyHistory> = try await worker.performRequest(with: request)
        return response
    }
}
