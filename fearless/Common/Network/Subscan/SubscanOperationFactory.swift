import Foundation
import RobinHood

protocol SubscanOperationFactoryProtocol {
    func fetchPriceOperation(_ url: URL, time: Int64) -> BaseOperation<PriceData>
}

final class SubscanOperationFactory: SubscanOperationFactoryProtocol {
    func fetchPriceOperation(_ url: URL, time: Int64) -> BaseOperation<PriceData> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpBody = try JSONEncoder().encode(PriceInfo(time: time))
            request.setValue(HttpContentType.json.rawValue,
                             forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<PriceData> { data in
            let resultData = try JSONDecoder().decode(SubscanStatusData<PriceData>.self,
                                                      from: data)

            guard resultData.isSuccess, let price = resultData.data else {
                throw SubscanError(statusData: resultData)
            }

            return price
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
