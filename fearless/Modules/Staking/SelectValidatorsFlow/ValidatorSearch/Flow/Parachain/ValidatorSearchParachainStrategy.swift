import Foundation
import RobinHood

protocol ValidatorSearchParachainStrategyOutput {
    func didReceiveValidatorInfo(_ validatorInfo: ParachainStakingCandidateInfo?)
    func didReceiveError(_ error: Error)
}

final class ValidatorSearchParachainStrategy {
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let output: ValidatorSearchParachainStrategyOutput?
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
    func performValidatorSearch(accountId _: AccountId) {}
}
