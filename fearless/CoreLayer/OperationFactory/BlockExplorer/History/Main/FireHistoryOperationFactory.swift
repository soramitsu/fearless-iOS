import Foundation
import SSFModels
import RobinHood

final class FireHistoryOperationFactory {
    private func createOperation(
        address: String,
        url: URL
    ) -> BaseOperation<FireHistoryResponse> {
        let requestFactory = BlockNetworkRequestFactory {
            var url = url
                .appendingPathComponent("transactions")
                .appendingPathComponent("address")
                .appendingPathComponent(address)

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue

            return request
        }

        let resultFactory = AnyNetworkResultFactory<FireHistoryResponse> { data, response, error in

            do {
                if let data = data {
                    let response = try GithubJSONDecoder().decode(
                        FireHistoryResponse.self,
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
        dependingOn remoteOperation: BaseOperation<FireHistoryResponse>,
        address: String,
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().data?.transactions

            let transactions = remoteTransactions?
                .compactMap {
                    AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
                }.filter { $0.amount.decimalValue > 0 }
                .sorted(by: { $0.timestamp > $1.timestamp }) ?? []

            return AssetTransactionPageData(transactions: transactions)
        }
    }
}

extension FireHistoryOperationFactory: HistoryOperationFactoryProtocol {
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
