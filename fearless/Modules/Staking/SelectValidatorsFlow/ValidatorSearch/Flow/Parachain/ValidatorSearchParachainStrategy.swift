import Foundation
import RobinHood

protocol ValidatorSearchParachainStrategyOutput {
    func didReceiveValidatorInfo(_ validatorInfo: ParachainStakingCandidateInfo?)
    func didReceiveError(_ error: Error)
}

final class ValidatorSearchParachainStrategy {
    let validatorOperationFactory: ValidatorOperationFactoryProtocol
    let operationManager: OperationManagerProtocol
    let output: ValidatorSearchParachainStrategyOutput?

    private var currentOperation: CompoundOperationWrapper<[ParachainStakingCandidateInfo]>?

    init(
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        output: ValidatorSearchParachainStrategyOutput?
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

extension ValidatorSearchParachainStrategy: ValidatorSearchStrategy {
    func setup() {}

    func performValidatorSearch(accountId _: AccountId) {
//        cancelSearch()
//
//        let searchOperation = validatorOperationFactory
//            .wannabeValidatorsOperation(for: [accountId])
//
//        currentOperation = searchOperation
//
//        searchOperation.targetOperation.completionBlock = { [weak self] in
//            DispatchQueue.main.async {
//                do {
//                    self?.currentOperation = nil
//                    let result = try searchOperation.targetOperation.extractNoCancellableResultData()
//
//                    guard let validatorInfo = result.first else {
//                        self?.output?.didReceiveValidatorInfo(nil)
//                        return
//                    }
//
//                    self?.output?.didReceiveValidatorInfo(validatorInfo)
//                } catch {
//                    self?.output?.didReceiveError(error)
//                }
//            }
//        }
//
//        operationManager.enqueue(operations: searchOperation.allOperations, in: .transient)
    }
}
