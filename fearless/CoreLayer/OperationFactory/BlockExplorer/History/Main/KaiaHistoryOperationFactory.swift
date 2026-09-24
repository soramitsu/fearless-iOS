import Foundation
import RobinHood
import SSFModels
#if canImport(FearlessKeys)
    import FearlessKeys
#endif

final class KaiaHistoryOperationFactory {
    struct Route {
        let configuredURL: URL
        let chainId: String
    }

    private static let paginationKey = "kaiaPage"

    static func supports(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return [
            "scope.klaytn.com", "scope.kaia.io",
            "mainnet-oapi.kaiascan.io", "kairos-oapi.kaiascan.io"
        ].contains(host)
    }

    private static func endpointHost(for route: Route) throws -> String {
        let configuredURL = route.configuredURL
        guard configuredURL.scheme == "https", configuredURL.user == nil,
              configuredURL.password == nil, configuredURL.port == nil,
              configuredURL.query == nil, configuredURL.fragment == nil,
              supports(url: configuredURL) else {
            throw KaiaHistoryError.invalidEndpoint
        }
        let expectedHost: String
        switch route.chainId {
        case "8217": expectedHost = "mainnet-oapi.kaiascan.io"
        case "1001": expectedHost = "kairos-oapi.kaiascan.io"
        default: throw KaiaHistoryError.invalidEndpoint
        }
        if configuredURL.host?.lowercased().contains("kaiascan.io") == true,
           configuredURL.host?.lowercased() != expectedHost {
            throw KaiaHistoryError.invalidEndpoint
        }
        return expectedHost
    }

    static func historyRequest(
        address: String,
        route: Route,
        tokenContract: String?,
        pagination: Pagination,
        apiKey: String
    ) throws -> (request: URLRequest, page: Int) {
        let expectedHost = try endpointHost(for: route)
        guard address.range(of: "^0x[0-9a-fA-F]{40}$", options: .regularExpression) != nil else {
            throw KaiaHistoryError.invalidEndpoint
        }
        guard !apiKey.isEmpty else { throw KaiaHistoryError.missingAPIKey }
        guard pagination.count >= 1, pagination.count <= 500 else {
            throw KaiaHistoryError.invalidPagination
        }
        let page = Int(pagination.context?[paginationKey] ?? "1") ?? 0
        guard page > 0, page < Int.max else { throw KaiaHistoryError.invalidPagination }
        if let tokenContract,
           tokenContract.range(of: "^0x[0-9a-fA-F]{40}$", options: .regularExpression) == nil {
            throw KaiaHistoryError.invalidEndpoint
        }

        let endpoint = tokenContract == nil ? "transactions" : "token-transfers"
        var components = URLComponents()
        components.scheme = "https"
        components.host = expectedHost
        components.path = "/api/v1/accounts/\(address)/\(endpoint)"
        components.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(pagination.count))
        ]
        if let tokenContract {
            components.queryItems?.append(URLQueryItem(name: "contractAddress", value: tokenContract))
        }
        guard let url = components.url else { throw KaiaHistoryError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = HttpMethod.get.rawValue
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return (request, page)
    }

    private static var apiKey: String {
        #if DEBUG
            return BlockExplorerApiKeysDebug.kaiaScanApiKey
        #else
            return BlockExplorerApiKeys.kaiaScanApiKey
        #endif
    }

    private func createOperation(
        request: URLRequest
    ) -> BaseOperation<KaiaHistoryResponse> {
        let requestFactory = BlockNetworkRequestFactory {
            request
        }

        let resultFactory = AnyNetworkResultFactory<KaiaHistoryResponse> { data, response, error in
            do {
                if let error {
                    return .failure(error)
                }
                guard let response = response as? HTTPURLResponse,
                      (200 ... 299).contains(response.statusCode) else {
                    throw KaiaHistoryError.invalidHTTPResponse
                }
                if let data = data {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let decoded = try decoder.decode(
                        KaiaHistoryResponse.self,
                        from: data
                    )
                    return .success(decoded)
                } else {
                    return .failure(SubqueryHistoryOperationFactoryError.incorrectInputData)
                }
            } catch {
                return .failure(error)
            }
        }

        return NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )
    }

    private func createMapOperation(
        dependingOn remoteOperation: BaseOperation<KaiaHistoryResponse>,
        address: String,
        chainAsset: ChainAsset,
        page: Int,
        tokenContract: String?
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let response = try remoteOperation.extractNoCancellableResultData()
            let remoteTransactions = try response.validatedTransactions(
                page: page, address: address, tokenContract: tokenContract
            )

            let transactions = try remoteTransactions
                .map {
                    try AssetTransactionData.createTransaction(
                        from: $0, address: address, chain: chainAsset.chain, asset: chainAsset.asset
                    )
                }.filter { $0.amount.decimalValue > 0 }
                .sorted(by: { $0.timestamp > $1.timestamp })

            let nextContext = response.paging.last ? nil : [Self.paginationKey: String(page + 1)]
            return AssetTransactionPageData(transactions: transactions, context: nextContext)
        }
    }
}

extension KaiaHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard let baseUrl = chain.externalApi?.history?.url else {
            return CompoundOperationWrapper.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let tokenContract: String? = asset.ethereumType == .erc20 || asset.ethereumType == .bep20 ? asset.id : nil
        let request: URLRequest
        let page: Int
        do {
            (request, page) = try Self.historyRequest(
                address: address,
                route: Route(configuredURL: baseUrl, chainId: chain.chainId),
                tokenContract: tokenContract,
                pagination: pagination,
                apiKey: Self.apiKey
            )
        } catch {
            return CompoundOperationWrapper.createWithError(error)
        }

        let remoteOperation = createOperation(request: request)

        let mapOperation = createMapOperation(
            dependingOn: remoteOperation,
            address: address,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            page: page,
            tokenContract: tokenContract
        )

        mapOperation.addDependency(remoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [remoteOperation])
    }
}
