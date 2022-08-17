import Foundation
import RobinHood

protocol ValidatorSearchRelaychainStrategyOutput {
    func didReceiveValidatorInfo(_ validatorInfo: SelectedValidatorInfo?)
    func didReceiveError(_ error: Error)
}

final class ValidatorSearchRelaychainStrategy {
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let output: ValidatorSearchRelaychainStrategyOutput?
    private var currentOperation: CompoundOperationWrapper<[SelectedValidatorInfo]>?

    init(
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        output: ValidatorSearchRelaychainStrategyOutput?
    ) {
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
        self.output = output
    }

    private func cancelSearch() {
        currentOperation?.cancel()
        currentOperation = nil
    }
}

extension ValidatorSearchRelaychainStrategy: ValidatorSearchStrategy {
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
                        self?.output?.didReceiveValidatorInfo(nil)
                        return
                    }

                    self?.output?.didReceiveValidatorInfo(validatorInfo)
                } catch {
                    self?.output?.didReceiveError(error)
                }
            }
        }

        operationManager.enqueue(operations: searchOperation.allOperations, in: .transient)
    }
}
