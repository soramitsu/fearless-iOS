import Foundation
import RobinHood

protocol ValidatorInfoParachainStrategyOutput {
    func didSetup()
}

final class ValidatorInfoParachainStrategy {
    let operationFactory: ParachainCollatorOperationFactory
    let operationManager: OperationManagerProtocol
    let collatorId: AccountId
    let output: ValidatorInfoParachainStrategyOutput?

    init(
        collatorId: AccountId,
        operationFactory: ParachainCollatorOperationFactory,
        operationManager: OperationManagerProtocol,
        output: ValidatorInfoParachainStrategyOutput?
    ) {
        self.operationFactory = operationFactory
        self.operationManager = operationManager
        self.collatorId = collatorId
        self.output = output
    }
}

extension ValidatorInfoParachainStrategy: ValidatorInfoStrategy {
    func setup() {
        output?.didSetup()
    }

    func reload() {}
}
