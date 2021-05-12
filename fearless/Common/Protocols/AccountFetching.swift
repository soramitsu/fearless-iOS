import Foundation
import RobinHood

protocol AccountFetching {
    func fetchAccount(
        for address: AccountAddress,
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    )

    func fetchAllAccounts(
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[AccountItem], Error>) -> Void
    )
}

extension AccountFetching {
    func fetchAccount(
        for address: AccountAddress,
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<AccountItem?, Error>) -> Void
    ) {
        let operation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func fetchAllAccounts(
        from repository: AnyDataProviderRepository<AccountItem>,
        operationManager: OperationManagerProtocol,
        closure: @escaping (Result<[AccountItem], Error>) -> Void
    ) {
        let operation = repository.fetchAllOperation(with: RepositoryFetchOptions())
        operation.completionBlock = {
            DispatchQueue.main.async {
                if let result = operation.result {
                    closure(result)
                } else {
                    closure(.failure(BaseOperationError.parentOperationCancelled))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}
