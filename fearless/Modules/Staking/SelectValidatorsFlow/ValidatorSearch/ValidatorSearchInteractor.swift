import Foundation
import RobinHood

final class ValidatorSearchInteractor {
    weak var presenter: ValidatorSearchInteractorOutputProtocol!

    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol

    init(
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
    }
}

extension ValidatorSearchInteractor: ValidatorSearchInteractorInputProtocol {
    func performValidatorSearch(accountId: AccountId) {
        let operation = validatorOperationFactory
            .wannabeValidatorsOperation(for: [accountId])

        operation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()

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

        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }
}
