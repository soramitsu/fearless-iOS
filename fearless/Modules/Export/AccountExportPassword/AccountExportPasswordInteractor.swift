import UIKit
import RobinHood

enum AccountExportPasswordInteractorError: Error {
    case missingAccount
    case invalidResult
}

final class AccountExportPasswordInteractor {
    weak var presenter: AccountExportPasswordInteractorOutputProtocol!

    let exportJsonWrapper: KeystoreExportWrapperProtocol
    let repository: AnyDataProviderRepository<AccountItem>
    let operationManager: OperationManagerProtocol

    init(exportJsonWrapper: KeystoreExportWrapperProtocol,
         repository: AnyDataProviderRepository<AccountItem>,
         operationManager: OperationManagerProtocol) {
        self.exportJsonWrapper = exportJsonWrapper
        self.repository = repository
        self.operationManager = operationManager
    }
}

extension AccountExportPasswordInteractor: AccountExportPasswordInteractorInputProtocol {
    func exportAccount(address: String, password: String) {
        let accountOperation = repository.fetchOperation(by: address, options: RepositoryFetchOptions())

        let exportOperation: BaseOperation<String> = ClosureOperation { [weak self] in
            guard let account = try accountOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled) else {
                throw AccountExportPasswordInteractorError.missingAccount
            }

            guard let data = try self?.exportJsonWrapper
                    .export(account: account, password: password) else {
                throw BaseOperationError.parentOperationCancelled
            }

            guard let result = String(data: data, encoding: .utf8) else {
                throw AccountExportPasswordInteractorError.invalidResult
            }

            return result
        }

        exportOperation.addDependency(accountOperation)

        exportOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let json = try exportOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    self?.presenter.didExport(json: json)
                } catch {
                    self?.presenter.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [accountOperation, exportOperation], in: .transient)
    }
}
