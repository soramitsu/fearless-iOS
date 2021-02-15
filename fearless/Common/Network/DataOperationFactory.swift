import Foundation
import RobinHood

protocol DataOperationFactoryProtocol {
    func fetchData(from url: URL) -> BaseOperation<Data>
}

final class DataOperationFactory: DataOperationFactoryProtocol {
    func fetchData(from url: URL) -> BaseOperation<Data> {
        let requestFactory = BlockNetworkRequestFactory {
            var request = URLRequest(url: url)
            request.httpMethod = HttpMethod.get.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<Data> { data in
            data
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
