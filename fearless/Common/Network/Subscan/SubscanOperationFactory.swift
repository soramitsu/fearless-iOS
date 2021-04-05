import Foundation
import RobinHood

protocol SubscanOperationFactoryProtocol {
    func fetchPriceOperation(_ url: URL, time: Int64) -> BaseOperation<PriceData>
    func fetchHistoryOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanHistoryData>
    func fetchRewardsAndSlashesOperation(_ url: URL, info: RewardInfo) -> BaseOperation<SubscanRewardData>

    func fetchExtrinsics(
        _ url: URL,
        info: ExtrinsicsInfo
    ) -> BaseOperation<SubscanExtrinsicsData>
}

final class SubscanOperationFactory: SubscanOperationFactoryProtocol {

    func fetchPriceOperation(_ url: URL, time: Int64) -> BaseOperation<PriceData> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpBody = try JSONEncoder().encode(PriceInfo(time: time))
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<PriceData> { data in
            let resultData = try JSONDecoder().decode(
                SubscanStatusData<PriceData>.self,
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

    func fetchHistoryOperation(_ url: URL, info: HistoryInfo) -> BaseOperation<SubscanHistoryData> {
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

        let resultFactory = AnyNetworkResultFactory<SubscanHistoryData> { data in
            let resultData = try JSONDecoder().decode(
                SubscanStatusData<SubscanHistoryData>.self,
                from: data
            )

            guard resultData.isSuccess, let history = resultData.data else {
                throw SubscanError(statusData: resultData)
            }

            return history
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func fetchRewardsAndSlashesOperation(_ url: URL, info: RewardInfo) -> BaseOperation<SubscanRewardData> {
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

        let resultFactory = AnyNetworkResultFactory<SubscanRewardData> { data in
            let resultData = try JSONDecoder().decode(
                SubscanStatusData<SubscanRewardData>.self,
                from: data
            )

            guard resultData.isSuccess, let history = resultData.data else {
                throw SubscanError(statusData: resultData)
            }

            return history
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func fetchExtrinsics(
        _ url: URL,
        info: ExtrinsicsInfo
    ) -> BaseOperation<SubscanExtrinsicsData> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubscanExtrinsicsData> { data in
            let resultData = try JSONDecoder().decode(
                SubscanStatusData<SubscanExtrinsicsData>.self,
                from: data)

            guard resultData.isSuccess, let extrinsics = resultData.data else {
                throw SubscanError(statusData: resultData)
            }

            return extrinsics
        }

        return NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)
    }
}
