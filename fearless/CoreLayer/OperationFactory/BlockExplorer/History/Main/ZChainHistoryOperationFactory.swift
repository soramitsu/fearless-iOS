import Foundation
import SSFModels
import RobinHood

final class ZChainHistoryOperationFactory {
    private func createOperation(
        address: String,
        url: URL
    ) -> BaseOperation<ZChainHistoryResponse> {
        let requestFactory = BlockNetworkRequestFactory {
            var url = url
                .appendingPathComponent("transaction")

            var urlComponents = URLComponents(string: url.absoluteString)
            let queryItems = [URLQueryItem(name: "a", value: address)]
            urlComponents?.queryItems = queryItems

            guard let urlWithParameters = urlComponents?.url else {
                return URLRequest(url: url)
            }

            url = urlWithParameters

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<ZChainHistoryResponse> { data, response, error in

            do {
                if let data = data {
                    let response = try GithubJSONDecoder().decode(
                        ZChainHistoryResponse.self,
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
        dependingOn remoteOperation: BaseOperation<ZChainHistoryResponse>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().data

            let transactions = remoteTransactions?
                .compactMap {
                    AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
                }.filter { $0.amount.decimalValue > 0 }
                .sorted(by: { $0.timestamp > $1.timestamp }) ?? []

            return AssetTransactionPageData(transactions: transactions)
        }
    }
}

extension ZChainHistoryOperationFactory: HistoryOperationFactoryProtocol {
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
            url: baseUrl
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
