import UIKit
import SoraKeystore
import IrohaCrypto
import RobinHood

class AddCreatedInteractor: BaseAccountConfirmInteractor {
    private var currentOperation: Operation?

    private func saveAccountItem(_ item: AccountItem) {
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
                    self?.presenter.didCompleteConfirmation()
                case .failure(let error):
                    self?.presenter?.didReceive(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [checkOperation, saveOperation],
                                 in: .sync)
    }

    override func createAccountUsingOperation(_ importOperation: BaseOperation<AccountItem>) {
        importOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                switch importOperation.result {
                case .success(let accountItem):
                    self?.saveAccountItem(accountItem)
                case .failure(let error):
                    self?.presenter?.didReceive(error: error)
                case .none:
                    let error = BaseOperationError.parentOperationCancelled
                    self?.presenter?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [importOperation],
                                 in: .sync)
    }
}
