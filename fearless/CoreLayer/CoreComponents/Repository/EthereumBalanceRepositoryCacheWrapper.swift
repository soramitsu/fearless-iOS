import Foundation
import RobinHood
import SSFModels

protocol RepositoryCacheWrapper: AnyObject {
    associatedtype T: Codable, Equatable

    func save(data: T?, identifier: String) throws
}

final class EthereumBalanceRepositoryCacheWrapper: RepositoryCacheWrapper {
    typealias T = AccountInfo

    private let logger: LoggerProtocol
    private let repository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    private let operationManager: OperationManagerProtocol

    private var cache: [String: T?] = [:]

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
        guard cache[identifier] != data else {
            return
        }

        let encoded = try JSONEncoder().encode(data)

        let storageWrapper = AccountInfoStorageWrapper(identifier: identifier, data: encoded)

        let operation = repository.saveOperation {
            [storageWrapper]
        } _: {
            []
        }

        operation.completionBlock = { [weak self] in
            self?.cache[identifier] = data
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
