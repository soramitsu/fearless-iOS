import Foundation
import RobinHood

import IrohaCrypto
import SSFUtils
import SSFModels
import FearlessKeys

final class OklinkHistoryOperationFactory {
    private func createOperation(
        address: String,
        url: URL,
        chainAsset: ChainAsset,
        page: String?
    ) -> BaseOperation<OklinkHistoryResponse> {
        var urlComponents = URLComponents(string: url.absoluteString)
        var queryItems = urlComponents?.queryItems
        queryItems?.append(URLQueryItem(name: "address", value: address))
        queryItems?.append(URLQueryItem(name: "symbol", value: chainAsset.asset.symbol))
        queryItems?.append(URLQueryItem(name: "page", value: page))

        switch chainAsset.asset.assetType.ethereumAssetType {
        case .erc20:
            queryItems?.append(URLQueryItem(name: "protocolType", value: "token_20"))
        case .bep20, .normal, .none:
            break
        }

        urlComponents?.queryItems = queryItems

        guard let urlWithParameters = urlComponents?.url else {
            return BaseOperation.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            var apiKey: String
            #if DEBUG
                apiKey = BlockExplorerApiKeysDebug.oklinkApiKey
            #else
                apiKey = BlockExplorerApiKeys.oklinkApiKey
            #endif
            request.setValue(apiKey, forHTTPHeaderField: "Ok-Access-Key")

            return request
        }

        let resultFactory = AnyNetworkResultFactory<OklinkHistoryResponse> { data, response, error in
            do {
                if let data = data {
                    let response = try JSONDecoder().decode(
                        OklinkHistoryResponse.self,
                        from: data
                    )

                    return .success(response)
                } else if let error = error {
                    return .failure(error)
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
        dependingOn remoteOperation: BaseOperation<OklinkHistoryResponse>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let response = try remoteOperation.extractNoCancellableResultData().data.first
            let remoteTransactions = response?.transactionLists
            let currentPage = (response?.page).flatMap { Int($0) }
            let totalPage = (response?.totalPage).flatMap { Int($0) }

            let transactions = remoteTransactions?
                .filter { asset.assetType.ethereumAssetType == .normal ? true : $0.tokenContractAddress.lowercased() == asset.id.lowercased() }
                .sorted(by: { $0.transactionTime > $1.transactionTime })
                .compactMap {
                    AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
                }.filter { $0.amount.decimalValue > 0 } ?? []

            let context: [String: String]? = response.flatMap {
                let currentPage = Int($0.page)
                let totalPage = Int($0.totalPage)
                
                guard let currentPage, let totalPage, currentPage < totalPage else {
                    return nil
                }
                
                let nextPageValue = "\(currentPage + 1)"
                return ["page" : nextPageValue]
            }
            
            return AssetTransactionPageData(transactions: transactions, context: context)
        }
    }
}

extension OklinkHistoryOperationFactory: HistoryOperationFactoryProtocol {
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

        let remoteOperation = createOperation(
            address: address,
            url: baseUrl,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            page: pagination.context?["page"]
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

struct OklinkHistoryResponse: Codable {
    let code, msg: String
    let data: [OklinkData]
}

struct OklinkData: Codable {
    let page, limit, totalPage, chainFullName: String
    let chainShortName: String
    let transactionLists: [OklinkTransactionItem]
}

struct OklinkTransactionItem: Codable {
    let txID, methodID, blockHash, height: String
    let transactionTime, from, to: String
    let isFromContract, isToContract: Bool?
    let amount, transactionSymbol, txFee, state: String
    let tokenID, tokenContractAddress, challengeStatus, l1OriginHash: String

    enum CodingKeys: String, CodingKey {
        case txID = "txId"
        case methodID = "methodId"
        case blockHash, height, transactionTime, from, to, isFromContract, isToContract, amount, transactionSymbol, txFee, state
        case tokenID = "tokenId"
        case tokenContractAddress, challengeStatus, l1OriginHash
    }
}
