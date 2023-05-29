import Foundation
import FearlessUtils
import BigInt

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
    func fetchBalances(for address: String) async throws -> AlchemyResponse<AlchemyBalance> {
        let smartContracts: [String] = ["0x6b175474e89094c44da98b954eedeac495271d0f"]
        let params = EthereumBalanceRequestParams(address: address, smartContracts: smartContracts)
        let body = JSONRPCInfo(identifier: 1, jsonrpc: "2.0", method: AlchemyEndpoint.tokenBalances.rawValue, params: params)
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorker()
        let response: AlchemyResponse<AlchemyBalance> = try await worker.performRequest(with: request)

        let addresses = response.result.tokenBalances.compactMap { $0.contractAddress }
        try await fetchTokenInfos(addresses: addresses)
        try await fetchEthBalance(address: address)
        return response
    }

    func fetchTokenInfos(addresses: [String]) async throws -> AlchemyResponse<AlchemyTokenMetadata> {
        let body = JSONRPCInfo(identifier: 2, jsonrpc: "2.0", method: AlchemyEndpoint.tokenMetadata.rawValue, params: [addresses.first!])
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorker()
        let response: AlchemyResponse<AlchemyTokenMetadata> = try await worker.performRequest(with: request)
        print("Metadata response: \(response.result)")
        return response
    }

    func fetchEthBalance(address: String) async throws -> AlchemyResponse<String> {
        let body = JSONRPCInfo(identifier: 3, jsonrpc: "2.0", method: AlchemyEndpoint.ethBalance.rawValue, params: [address, "latest"])
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorker()
        let response: AlchemyResponse<String> = try await worker.performRequest(with: request)
        guard let balanceData = try? Data(hexString: response.result) else {
            throw CommonError.network
        }
        let balance = BigUInt(balanceData)
        print("Eth balance response: \(balance)")
        return response
    }

    func fetchTransactionHistory(request: AlchemyHistoryRequest) async throws -> AlchemyResponse<AlchemyHistory> {
        let body = JSONRPCInfo(identifier: 4, jsonrpc: "2.0", method: AlchemyEndpoint.getAssetTransfers.rawValue, params: [request])
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorker()
        let response: AlchemyResponse<AlchemyHistory> = try await worker.performRequest(with: request)
        return response
    }

    func fetchGasPrice() async throws -> AlchemyResponse<String> {
        let body = JSONRPCInfo<String?>(identifier: 5, jsonrpc: "2.0", method: AlchemyEndpoint.ethGasPrice.rawValue, params: nil)
        let paramsEncoded = try JSONEncoder().encode(body)
        let request = AlchemyRequest(body: paramsEncoded)
        let worker = NetworkWorker()
        let response: AlchemyResponse<String> = try await worker.performRequest(with: request)
        guard let balanceData = try? Data(hexString: response.result) else {
            throw CommonError.network
        }
        let balance = BigUInt(balanceData)
        print("gas price response: \(balance)")
        return response
    }

    func estimateGas(to _: String, value _: BigUInt) {}
}
