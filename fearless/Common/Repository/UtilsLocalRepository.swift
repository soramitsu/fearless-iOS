import Foundation
import RobinHood

final class UtilsLocalRepository<T: Codable & Equatable> {
    private let url: URL
    private let logger: LoggerProtocol?
    private var cache: T?
    private let fileRepository: FileRepositoryProtocol

    private var filename: String? {
        guard let filename = url.absoluteString.sha256String() else {
            return nil
        }

        return URL.documentsDirectoryUrl().appendingPathComponent(filename).path
    }

    init(url: URL, logger: LoggerProtocol?) {
        self.url = url
        self.logger = logger

        fileRepository = FileRepository()

        cache = readFromFile()

        load { [weak self] result in
            switch result {
            case let .success(resultData):
                self?.cache = resultData

                self?.saveToFile(data: resultData)
            case let .failure(error):
                logger?.error(error.localizedDescription)
            }
        }
    }

    func fetch() -> T? {
        cache
    }

    private func readFromFile() -> T? {
        guard let filename = filename else {
            return nil
        }

        let readOperation = fileRepository.readOperation(at: filename)

        let queue = OperationQueue()

        queue.addOperations([readOperation], waitUntilFinished: true)

        guard let data = try? readOperation.extractNoCancellableResultData() else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveToFile(data: T) {
        guard let filename = filename else {
            return
        }

        let queue = OperationQueue()

        let writeOperation = fileRepository.writeOperation(dataClosure: {
            try JSONEncoder().encode(data)
        }, at: filename)

        queue.addOperation(writeOperation)
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
