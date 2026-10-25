import Foundation
import RobinHood

import IrohaCrypto
import SSFUtils
import SSFModels

final class EtherscanHistoryOperationFactory {
    /// Public Etherscan-compatible Routescan API for Avalanche C-Chain. It is not an Etherscan V2
    /// host, so `historyURL` keeps it unchanged and never attaches the unified explorer key.
    static let avalancheHistoryURL = URL(string: "https://api.routescan.io/v2/network/mainnet/evm/43114/etherscan/api")
    static let maxPageSize = 100

    private static let v2ChainByHost = [
        "api.etherscan.io": "1",
        "api-goerli.etherscan.io": "5",
        "api-sepolia.etherscan.io": "11155111",
        "api.bscscan.com": "56",
        "api-testnet.bscscan.com": "97",
        "api.polygonscan.com": "137",
        "api-testnet.polygonscan.com": "80001"
    ]

    private let baseURL: URL?
    private let session: URLSession

    init(baseURL: URL? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static func historyURL(
        address: String,
        baseURL: URL,
        chainId: String,
        action: String,
        unifiedAPIKey: String,
        additionalQueryItems: [URLQueryItem] = []
    ) throws -> URL {
        guard baseURL.scheme == "https", let host = baseURL.host?.lowercased() else {
            throw EtherscanHistoryError.invalidEndpoint
        }
        let usesV2 = v2ChainByHost[host] != nil
        if let expectedChainId = v2ChainByHost[host] {
            guard chainId == expectedChainId, baseURL.path == "/api",
                  baseURL.query == nil, baseURL.fragment == nil else {
                throw EtherscanHistoryError.invalidEndpoint
            }
        }
        let endpoint: URL
        if usesV2 {
            guard let v2URL = URL(string: "https://api.etherscan.io/v2/api") else {
                throw EtherscanHistoryError.invalidEndpoint
            }
            endpoint = v2URL
        } else {
            endpoint = baseURL
        }
        if usesV2, unifiedAPIKey.isEmpty {
            throw EtherscanHistoryError.missingAPIKey
        }
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw EtherscanHistoryError.invalidEndpoint
        }
        var queryItems = [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "address", value: address)
        ]
        if usesV2 {
            queryItems.insert(URLQueryItem(name: "chainid", value: chainId), at: 0)
        }
        queryItems += additionalQueryItems
        if usesV2 {
            queryItems.append(URLQueryItem(name: "apikey", value: unifiedAPIKey))
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw EtherscanHistoryError.invalidEndpoint
        }
        return url
    }

    private static var unifiedAPIKey: String {
        #if DEBUG
            return BlockExplorerApiKeysDebug.etherscanApiKey
        #else
            return BlockExplorerApiKeys.etherscanApiKey
        #endif
    }

    func fetchPage(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        pagination: Pagination
    ) async throws -> AssetTransactionPageData {
        let request = try makeRequest(asset: asset, chain: chain, address: address, pagination: pagination)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if Task.isCancelled { throw CancellationError() }
            // URL errors carry the request URL, which may include the explorer key.
            throw EtherscanHistoryError.requestFailed
        }
        guard let response = response as? HTTPURLResponse,
              (200 ... 299).contains(response.statusCode) else {
            throw EtherscanHistoryError.invalidHTTPResponse
        }
        guard let remote = try? JSONDecoder().decode(EtherscanHistoryResponse.self, from: data) else {
            throw EtherscanHistoryError.providerRejected
        }

        let transactions = remote.result
            .filter {
                asset.ethereumType == .normal ? true : $0.contractAddress?.lowercased() == asset.id.lowercased()
            }
            .filter { $0.hash?.isEmpty == false && $0.timestampInSeconds > 0 }
            .sorted(by: { $0.timestampInSeconds > $1.timestampInSeconds })
            .map {
                AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
            }.filter { $0.amount.decimalValue > 0 }

        // Advance by the provider's page size, not by the rows left after the asset filter.
        let limit = min(pagination.count, Self.maxPageSize)
        let currentPage = Int(pagination.context?[PaginationKey.page] ?? "1") ?? 1
        let context: PaginationContext? = remote.result.count >= limit ? [
            PaginationKey.page: String(currentPage + 1),
            PaginationKey.chainId: chain.chainId,
            PaginationKey.address: address.lowercased(),
            PaginationKey.assetId: asset.id.lowercased(),
            PaginationKey.limit: String(limit)
        ] : nil
        return AssetTransactionPageData(transactions: transactions, context: context)
    }

    func makeRequest(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        pagination: Pagination
    ) throws -> URLRequest {
        guard pagination.count >= 1, let endpoint = baseURL ?? chain.externalApi?.history?.url else {
            throw EtherscanHistoryError.invalidEndpoint
        }
        let limit = min(pagination.count, Self.maxPageSize)
        var page = 1
        if let context = pagination.context {
            // A cursor is only valid for the account, asset, network and page size that produced it.
            guard let value = context[PaginationKey.page], let parsed = Int(value), parsed > 0, parsed < Int.max,
                  context[PaginationKey.chainId] == chain.chainId,
                  context[PaginationKey.address] == address.lowercased(),
                  context[PaginationKey.assetId] == asset.id.lowercased(),
                  context[PaginationKey.limit] == String(limit) else {
                throw EtherscanHistoryError.invalidCursor
            }
            page = parsed
        }

        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "offset", value: String(limit)),
            URLQueryItem(name: "sort", value: "desc")
        ]
        if asset.ethereumType != .normal {
            queryItems.insert(URLQueryItem(name: "contractaddress", value: asset.id), at: 0)
        }

        let url = try Self.historyURL(
            address: address,
            baseURL: endpoint,
            chainId: chain.chainId,
            action: asset.ethereumType == .normal ? "txlist" : "tokentx",
            unifiedAPIKey: Self.unifiedAPIKey,
            additionalQueryItems: queryItems
        )
        var request = URLRequest(url: url)
        request.httpMethod = HttpMethod.get.rawValue
        request.timeoutInterval = 30
        return request
    }
}

extension EtherscanHistoryOperationFactory {
    enum PaginationKey {
        static let page = "etherscanPage"
        static let chainId = "chainId"
        static let address = "address"
        static let assetId = "assetId"
        static let limit = "limit"
    }
}

extension EtherscanHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        // Etherscan-compatible APIs only return transfers.
        if !filters.isEmpty, !filters.contains(where: { $0.type == .transfer && $0.selected }) {
            return .createWithResult(AssetTransactionPageData(transactions: []))
        }

        let operation = AwaitOperation<AssetTransactionPageData?> {
            try await self.fetchPage(asset: asset, chain: chain, address: address, pagination: pagination)
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }
}
