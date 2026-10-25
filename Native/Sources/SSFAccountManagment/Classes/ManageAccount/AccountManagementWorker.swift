import Foundation
import RobinHood
import SSFAccountManagmentStorage
import SSFModels
import SSFUtils

// sourcery: AutoMockable
public protocol AccountManagementWorkerProtocol {
    func save(account: ManagedMetaAccountModel, completion: @escaping () -> Void)
    func fetchAll() async throws -> [MetaAccountModel]
    func deleteAll(completion: @escaping () -> Void)
}

enum AccountManagementWorkerError: Error {
    case unexpected
}

public final class AccountManagementWorker: AccountManagementWorkerProtocol {
    private let metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>
    private let managedAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>
    private let operationQueue: OperationQueue

    public init(
        metaAccountRepository: AnyDataProviderRepository<MetaAccountModel>,
        managedAccountRepository: AnyDataProviderRepository<ManagedMetaAccountModel>,
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.operationQueue = operationQueue
        self.metaAccountRepository = metaAccountRepository
        self.managedAccountRepository = managedAccountRepository
    }

    deinit {
        operationQueue.cancelAllOperations()
    }

    public func save(account: ManagedMetaAccountModel, completion: @escaping () -> Void) {
        let saveOperation = managedAccountRepository.saveOperation { [account] } _: { [] }
        saveOperation.completionBlock = completion
        operationQueue.addOperations([saveOperation], waitUntilFinished: true)
    }

    public func fetchAll() async throws -> [MetaAccountModel] {
        let fetchOperation = metaAccountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        operationQueue.addOperation(fetchOperation)

        return try await withUnsafeThrowingContinuation { continuation in
            fetchOperation.completionBlock = {
                do {
                    let result = try fetchOperation.extractNoCancellableResultData()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func deleteAll(completion: @escaping () -> Void) {
        let deleteAllOperation = managedAccountRepository.deleteAllOperation()
        deleteAllOperation.completionBlock = completion
        operationQueue.addOperation(deleteAllOperation)
    }
}
