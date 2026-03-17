import Foundation
import RobinHood
import SSFModels

protocol RepositoryCacheWrapper: AnyObject {
    associatedtype T: Codable, Equatable

    func save(data: T?, identifier: String) throws
    func save(map: [String: T?]) throws
}

final class BalanceRepositoryCacheWrapper: RepositoryCacheWrapper {
    typealias T = AccountInfo

    private let logger: LoggerProtocol
    private let repository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    private let operationManager: OperationManagerProtocol

    private lazy var encoder = JSONEncoder()
    private lazy var decoder = JSONDecoder()

    private var cache: [String: T?] = [:]
    private let lock = ReaderWriterLock()

    init(
        logger: LoggerProtocol,
        repository: AnyDataProviderRepository<AccountInfoStorageWrapper>,
        operationManager: OperationManagerProtocol
    ) {
        self.logger = logger
        self.repository = repository
        self.operationManager = operationManager
    }

    func save(data: T?, identifier: String) throws {
        lock.concurrentlyRead {
            guard cache[identifier] != data else {
                return
            }
        }

        let encoded = try encoder.encode(data)

        let storageWrapper = AccountInfoStorageWrapper(identifier: identifier, data: encoded)
        save([storageWrapper])
    }

    func save(map: [String: T?]) throws {
        let wrappers = try map.map { identifier, data in
            let encoded = try encoder.encode(data)
            return AccountInfoStorageWrapper(identifier: identifier, data: encoded)
        }

        save(wrappers)
    }

    private func save(_ wrappers: [AccountInfoStorageWrapper]) {
        let operation = repository.saveOperation {
            wrappers
        } _: { [] }

        operation.completionBlock = { [weak self] in
            self?.lock.exclusivelyWrite {
                wrappers.forEach { wrapper in
                    let decoded = try? self?.decoder.decode(T.self, from: wrapper.data)
                    self?.cache[wrapper.identifier] = decoded
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
