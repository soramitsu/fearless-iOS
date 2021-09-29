import Foundation
import RobinHood

protocol SubscanOperationFactoryProtocol {
    func fetchTransfersOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanTransferData>
    func fetchRewardsAndSlashesOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanRewardData>
    func fetchConcreteExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) ->
        BaseOperation<SubscanConcreteExtrinsicsData>
    func fetchRawExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) -> BaseOperation<SubscanRawExtrinsicsData>
}

final class SubscanOperationFactory {
    private func fetchOperation<Request: Encodable, Response: Decodable>(
        _ url: URL,
        info: Request
    ) -> BaseOperation<Response> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.setValue(
                SubscanCIKeys.apiKey, forHTTPHeaderField: "X-API-Key"
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Response> { data in
            let result = try JSONDecoder().decode(
                SubscanStatusData<Response>.self,
                from: data
            )

            guard result.isSuccess, let resultData = result.data else {
                throw SubscanError(statusData: result)
            }

            return resultData
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}

extension SubscanOperationFactory: SubscanOperationFactoryProtocol {
    func fetchTransfersOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanTransferData> {
        fetchOperation(url, info: info)
    }

    func fetchRewardsAndSlashesOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanRewardData> {
        fetchOperation(url, info: info)
    }

    func fetchConcreteExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) ->
        BaseOperation<SubscanConcreteExtrinsicsData> {
        fetchOperation(url, info: info)
    }

    func fetchRawExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) -> BaseOperation<SubscanRawExtrinsicsData> {
        fetchOperation(url, info: info)
    }
}
