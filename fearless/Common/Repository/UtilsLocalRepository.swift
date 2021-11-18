import Foundation
import RobinHood

final class UtilsLocalRepository<T: Codable & Equatable> {
    private let url: URL
    private let logger: LoggerProtocol?
    private var cache: T?

    private var filename: String? {
        guard let filename = url.absoluteString.sha256String() else {
            return nil
        }

        return URL.documentsDirectoryUrl().appendingPathComponent(filename).path
    }

    init(url: URL, logger: LoggerProtocol?, repository: AnyDataProviderRepository<T>) {
        self.url = url
        self.logger = logger

        cache = readFromRepository()

        load { [weak self] result in
            switch result {
            case let .success(resultData):
                self?.cache = resultData
            case let .failure(error):
                logger?.error(error.localizedDescription)
            }
        }
    }

    func fetch() -> T? {
        cache
    }

    private func readFromRepository() -> T? {
        let databaseRepository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> =
            SubstrateDataStorageFacade.shared.createRepository()
        let repository = AnyDataProviderRepository(databaseRepository)
        let fetchOperaion = repository.fetchOperation(by: url.absoluteString,
                                                      options: RepositoryFetchOptions.onlyProperties)

        let queue = OperationQueue()

        queue.addOperations([fetchOperaion], waitUntilFinished: true)

        guard let data = try? fetchOperaion.extractNoCancellableResultData()?.payload else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func load(completion: @escaping (Result<T, Error>) -> Void) {
        let providerFactory = SingleValueProviderFactory.shared
        let provider: AnySingleValueProvider<T> = providerFactory.getJson(for: url)

        let updateClosure: ([DataProviderChange<T>]) -> Void = { changes in
            if let result = changes.reduceToLastChange() {
                completion(.success(result))
            }
        }

        let failureClosure: (Error) -> Void = { error in
            completion(.failure(error))
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: true
        )

        provider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .utility),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }
}
