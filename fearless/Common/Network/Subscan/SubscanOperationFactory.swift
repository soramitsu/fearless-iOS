import Foundation
import RobinHood
import Network

protocol SubscanOperationFactoryProtocol {
    func fetchTransfersOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanTransferData>
    func fetchRewardsAndSlashesOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanRewardData>
    func fetchConcreteExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) ->
        BaseOperation<SubscanConcreteExtrinsicsData>
    func fetchRawExtrinsicsOperation(_ url: URL, info: ExtrinsicsInfo) -> BaseOperation<SubscanRawExtrinsicsData>
    func fetchAllExtrinsicForCall<T: Decodable>(_ url: URL, call: CallCodingPath, historyInfo: HistoryInfo, of _: T.Type) -> BaseOperation<T>
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

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
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

    func fetchAllExtrinsicForCall<T: Decodable>(_ url: URL, call: CallCodingPath, historyInfo: HistoryInfo, of _: T.Type) -> BaseOperation<T> {
        let info = ExtrinsicsInfo(
            row: historyInfo.row,
            page: historyInfo.page,
            address: historyInfo.address,
            moduleName: call.moduleName,
            callName: call.callName
        )
        return fetchOperation(url, info: info)
    }
}
