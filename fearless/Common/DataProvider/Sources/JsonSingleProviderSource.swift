import Foundation
import RobinHood

final class JsonSingleProviderSource<T: Decodable> {
    let url: URL

    private lazy var operationFactory = DataOperationFactory()

    init(url: URL) {
        self.url = url
    }
}

extension JsonSingleProviderSource: SingleValueProviderSourceProtocol {
    typealias Model = T

    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        let dataOperation = operationFactory.fetchData(from: url)

        let mapOperation = ClosureOperation<Model?> {
            let data = try dataOperation.extractNoCancellableResultData()
            return try JSONDecoder().decode(T.self, from: data)
        }

        mapOperation.addDependency(dataOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [dataOperation])
    }
}
