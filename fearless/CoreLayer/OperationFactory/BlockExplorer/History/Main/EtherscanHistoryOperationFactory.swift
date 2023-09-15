import Foundation
import RobinHood
import CommonWallet
import IrohaCrypto
import SSFUtils
import SSFModels
import FearlessKeys

final class EtherscanHistoryOperationFactory {
    private func createOperation(
        address: String,
        url: URL,
        chainAsset: ChainAsset
    ) -> BaseOperation<EtherscanHistoryResponse> {
        let action: String = chainAsset.asset.ethereumType == .normal ? "txlist" : "tokentx"
        var urlComponents = URLComponents(string: url.absoluteString)
        urlComponents?.queryItems = [
            URLQueryItem(name: "module", value: "account"),
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "address", value: address),
            URLQueryItem(name: "apikey", value: BlockExplorerApiKeys.etherscanApiKey)
        ]

        guard let urlWithParameters = urlComponents?.url else {
            return BaseOperation.createWithError(SubqueryHistoryOperationFactoryError.urlMissing)
        }

        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: urlWithParameters)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<EtherscanHistoryResponse> { data, response, error in

            do {
                if let data = data {
                    let response = try JSONDecoder().decode(
                        EtherscanHistoryResponse.self,
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
        dependingOn remoteOperation: BaseOperation<EtherscanHistoryResponse>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().result

            let transactions = remoteTransactions
                .filter { asset.ethereumType == .normal ? true : $0.contractAddress.lowercased() == asset.id.lowercased() }
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
