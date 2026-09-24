import Foundation
import RobinHood
import SSFModels

final class KaiaHistoryOperationFactory {
    private func createOperation(
        address: String,
        url: URL
    ) -> BaseOperation<KaiaHistoryResponse> {
        let requestFactory = BlockNetworkRequestFactory {
            let url = url
                .appendingPathComponent("accounts")
                .appendingPathComponent(address)
                .appendingPathComponent("txs")

            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue

            return request
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
                    let decoded = try GithubJSONDecoder().decode(
                        KaiaHistoryResponse.self,
                        from: data
                    )
                    _ = try decoded.validatedTransactions()
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
        asset: AssetModel,
        chain: ChainModel
    ) -> BaseOperation<AssetTransactionPageData?> {
        ClosureOperation {
            let remoteTransactions = try remoteOperation.extractNoCancellableResultData().validatedTransactions()

            let transactions = remoteTransactions
                .compactMap {
                    AssetTransactionData.createTransaction(from: $0, address: address, chain: chain, asset: asset)
                }.filter { $0.amount.decimalValue > 0 }
                .sorted(by: { $0.timestamp > $1.timestamp })

            return AssetTransactionPageData(transactions: transactions)
        }
    }
}

extension KaiaHistoryOperationFactory: HistoryOperationFactoryProtocol {
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
