import Foundation
import RobinHood

protocol SubscanOperationFactoryProtocol {
    func fetchPriceOperation(_ url: URL, time: Int64) -> BaseOperation<PriceData>
    func fetchTransfersOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanTransferData>
    func fetchRewardsAndSlashesOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanRewardData>
    func fetchConcreteExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) ->
        BaseOperation<SubscanConcreteExtrinsicsData>
    func fetchExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) -> BaseOperation<SubscanExtrinsicsData>
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
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Response> { data in
            let resultData = try JSONDecoder().decode(
                SubscanStatusData<Response>.self,
                from: data
            )

            guard resultData.isSuccess, let price = resultData.data else {
                throw SubscanError(statusData: resultData)
            }

            return price
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}

extension SubscanOperationFactory: SubscanOperationFactoryProtocol {
    func fetchPriceOperation(_ url: URL, time: Int64) -> BaseOperation<PriceData> {
        let info = PriceInfo(time: time)
        return fetchOperation(url, info: info)
    }

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

    func fetchExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) -> BaseOperation<SubscanExtrinsicsData> {
        fetchOperation(url, info: info)
    }

    func fetchRawExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) -> BaseOperation<SubscanRawExtrinsicsData> {
        fetchOperation(url, info: info)
    }
}
