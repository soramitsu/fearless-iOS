import Foundation
import RobinHood

public protocol NetworkOperationFactoryProtocol {
    func fetchData<T: Decodable>(from url: URL) -> BaseOperation<T>
}

public final class NetworkOperationFactory: NetworkOperationFactoryProtocol {
    private let jsonDecoder: JSONDecoder

    public init(jsonDecoder: JSONDecoder = JSONDecoder()) {
        self.jsonDecoder = jsonDecoder
    }

    public func fetchData<T: Decodable>(from url: URL) -> BaseOperation<T> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<T> { data in
            let result = try self.jsonDecoder.decode(T.self, from: data)
            return result
        }

        let operation = NetworkOperation(
            requestFactory: requestFactory,
            resultFactory: resultFactory
        )

        return operation
    }
}
