import Foundation
import RobinHood
import SSFModels

enum EtherscanHistoryError: LocalizedError {
    case invalidConfiguration, invalidCursor, invalidResponse

    var errorDescription: String? {
        "Transaction history is temporarily unavailable. Please try again."
    }
}

final class EtherscanHistoryOperationFactory: HistoryOperationFactoryProtocol {
    static let avalancheHistoryURL = URL(string: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan/api")
    private let baseURL: URL?
    private let session: URLSession

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        if !filters.isEmpty, !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            return .createWithResult(AssetTransactionPageData(transactions: []))
        }
        let operation = AwaitOperation<AssetTransactionPageData?> {
            try await self.fetchPage(asset: asset, chain: chain, address: address, pagination: pagination)
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchPage(asset: AssetModel, chain: ChainModel, address: String, pagination: Pagination) async throws -> AssetTransactionPageData {
        let request = try makeRequest(asset: asset, chain: chain, address: address, pagination: pagination)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            throw EtherscanHistoryError.invalidResponse
        }
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              let remote = try? JSONDecoder().decode(EtherscanHistoryResponse.self, from: data),
              let items = remote.result,
              remote.status == "1" || (remote.status == "0" && remote.message == "No transactions found" && items.isEmpty) else {
            throw EtherscanHistoryError.invalidResponse
        }
        let transactions = items
            .filter { asset.ethereumType == .normal || $0.contractAddress?.lowercased() == asset.id.lowercased() }
            .filter { $0.hash?.isEmpty == false && $0.timestampInSeconds > 0 }
            .sorted { $0.timestampInSeconds > $1.timestampInSeconds }
            .map { AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset) }
        let limit = min(pagination.count, 100)
        let currentPage = Int(pagination.context?["etherscanPage"] ?? "1") ?? 1
        let context: PaginationContext? = items.count >= limit ? [
            "etherscanPage": String(currentPage + 1), "chainId": chain.chainId,
            "address": address.lowercased(), "assetId": asset.id.lowercased(), "limit": String(limit)
        ] : nil
        return AssetTransactionPageData(transactions: transactions, context: context)
    }

    func makeRequest(asset: AssetModel, chain: ChainModel, address: String, pagination: Pagination) throws -> URLRequest {
        guard pagination.count >= 1, let endpoint = baseURL ?? chain.externalApi?.history?.url,
              endpoint.scheme == "https", var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw EtherscanHistoryError.invalidConfiguration
        }
        let limit = min(pagination.count, 100)
        var page = 1
        if let context = pagination.context {
            guard let value = context["etherscanPage"], let parsed = Int(value), parsed > 0, parsed < Int.max,
                  context["chainId"] == chain.chainId, context["address"] == address.lowercased(),
                  context["assetId"] == asset.id.lowercased(), context["limit"] == String(limit) else {
                throw EtherscanHistoryError.invalidCursor
            }
            page = parsed
        }
        let controlled = Set(["module", "action", "address", "contractaddress", "page", "offset", "sort", "apikey"])
        var query = (components.queryItems ?? []).filter { !controlled.contains($0.name.lowercased()) }
        query += [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: asset.ethereumType == .normal ? "txlist" : "tokentx"),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "offset", value: String(limit)),
            URLQueryItem(name: "sort", value: "desc")
        ]
        if asset.ethereumType != .normal {
            query.append(URLQueryItem(name: "contractaddress", value: asset.id))
        }
        // Routescan is public. An override must never receive another provider's credential.
        if baseURL == nil, let apiKey = BlockExplorerApiKey(chainId: chain.chainId), !apiKey.value.isEmpty {
            query.append(URLQueryItem(name: "apikey", value: apiKey.value))
        }
        components.queryItems = query
        guard let url = components.url else { throw EtherscanHistoryError.invalidConfiguration }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        return request
    }
}
