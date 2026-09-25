import Foundation
import RobinHood

import IrohaCrypto
import SSFUtils
import SSFModels
#if canImport(FearlessKeys)
    import FearlessKeys
#endif

final class EtherscanHistoryOperationFactory {
    private static let v2ChainByHost = [
        "api.etherscan.io": "1",
        "api-goerli.etherscan.io": "5",
        "api-sepolia.etherscan.io": "11155111",
        "api.bscscan.com": "56",
        "api-testnet.bscscan.com": "97",
        "api.polygonscan.com": "137",
        "api-testnet.polygonscan.com": "80001"
    ]

    static func historyURL(
        address: String,
        baseURL: URL,
        chainId: String,
        action: String,
        unifiedAPIKey: String
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

    private func createOperation(
        address: String,
        url: URL,
        chainAsset: ChainAsset
    ) -> BaseOperation<EtherscanHistoryResponse> {
        let action: String = chainAsset.asset.ethereumType == .normal ? "txlist" : "tokentx"
        let urlWithParameters: URL
        do {
            urlWithParameters = try Self.historyURL(
                address: address,
                baseURL: url,
                chainId: chainAsset.chain.chainId,
                action: action,
                unifiedAPIKey: Self.unifiedAPIKey
            )
        } catch {
            return BaseOperation.createWithError(error)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<EtherscanHistoryResponse> { data, response, error in

            do {
                if let error { return .failure(error) }
                guard let response = response as? HTTPURLResponse,
                      (200 ... 299).contains(response.statusCode) else {
                    throw EtherscanHistoryError.invalidHTTPResponse
                }
                if let data = data {
                    let decoded = try JSONDecoder().decode(
                        EtherscanHistoryResponse.self,
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

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }

    private func createMapOperation(
        dependingOn remoteOperation: BaseOperation<EtherscanHistoryResponse>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().result

            let transactions = remoteTransactions
                .filter {
                    asset.ethereumType == .normal ? true : $0.contractAddress?.lowercased() == asset.id.lowercased()
                }
                .sorted(by: { $0.timestampInSeconds > $1.timestampInSeconds })
                .compactMap {
                    AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
                }.filter { $0.amount.decimalValue > 0 }

            return AssetTransactionPageData(transactions: transactions)
        }
    }
}

extension EtherscanHistoryOperationFactory: HistoryOperationFactoryProtocol {
    func fetchTransactionHistoryOperation(
        asset: AssetModel,
        chain: ChainModel,
        address: String,
        filters _: [WalletTransactionHistoryFilter],
        pagination _: Pagination
    ) -> CompoundOperationWrapper<AssetTransactionPageData?> {
        guard let baseUrl = chain.externalApi?.history?.url else {
            return CompoundOperationWrapper.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let remoteOperation = createOperation(
            address: address,
            url: baseUrl,
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )

        let mapOperation = createMapOperation(
            dependingOn: remoteOperation,
            address: address,
            asset: asset,
            chain: chain
        )

        mapOperation.addDependency(remoteOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [remoteOperation])
    }
}
