import Foundation
import RobinHood

final class ValidatorSearchInteractor {
    weak var presenter: ValidatorSearchInteractorOutputProtocol!

    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var currentOperation: CompoundOperationWrapper<[SelectedValidatorInfo]>?

    init(
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
    }

    private func cancelSearch() {
        currentOperation?.cancel()
        currentOperation = nil
    }
}

extension ValidatorSearchInteractor: ValidatorSearchInteractorInputProtocol {
    func performValidatorSearch(accountId: AccountId) {
        cancelSearch()

        let searchOperation = validatorOperationFactory
            .wannabeValidatorsOperation(for: [accountId])

        currentOperation = searchOperation

        searchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    self?.currentOperation = nil
                    let result = try searchOperation.targetOperation.extractNoCancellableResultData()

                    guard let validatorInfo = result.first else {
                        self?.presenter.didReceiveValidatorInfo(result: .success(nil))
                        return
                    }

                    self?.presenter.didReceiveValidatorInfo(result: .success(validatorInfo))
                } catch {
                    self?.presenter.didReceiveValidatorInfo(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: searchOperation.allOperations, in: .transient)
    }
}
