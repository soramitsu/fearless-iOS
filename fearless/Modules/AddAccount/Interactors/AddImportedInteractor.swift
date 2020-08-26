import UIKit
import IrohaCrypto
import FearlessUtils
import RobinHood
import SoraKeystore

final class AddImportedInteractor: BaseAccountImportInteractor {

    private func importAccountItem(_ item: AccountItem) {
        let fetchOptions = RepositoryFetchOptions()
        let checkOperation = accountRepository.fetchOperation(by: item.address,
                                                              options: fetchOptions)

        let saveOperation = accountRepository.saveOperation({
            if try checkOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) != nil {
                throw AddAccountError.duplicated
            }

            return [item]
        }, { [] })

        saveOperation.addDependency(checkOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch saveOperation.result {
                case .success:
                    self?.presenter.didCompleAccountImport()
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [checkOperation, saveOperation],
                                 in: .sync)
    }

    override func importAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        importOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch importOperation.result {
                case .success(let accountItem):
                    self?.importAccountItem(accountItem)
                case .failure(let error):
                    self?.presenter?.didReceiveAccountImport(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceiveAccountImport(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation],
                                 in: .sync)
    }
}
