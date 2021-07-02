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
            .pendingValidatorsOperation(for: [accountId])

        operation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()

                    guard let validatorInfo = result.first else {
                        self?.presenter.didReceiveValidatorInfo(result: .success(nil))
                        return
                    }

                    let nominatorsStake = validatorInfo.stakeInfo?.nominators
                        .map(\.stake)
                        .reduce(0, +) ?? 0.0

                    let validator = ElectedValidatorInfo(
                        address: validatorInfo.address,
                        nominators: validatorInfo.stakeInfo?.nominators ?? [],
                        totalStake: validatorInfo.stakeInfo?.totalStake ?? 0.0,
                        ownStake: (validatorInfo.stakeInfo?.totalStake ?? 0.0) - nominatorsStake,
                        comission: 0.0,
                        identity: validatorInfo.identity,
                        stakeReturn: validatorInfo.stakeInfo?.stakeReturn ?? 0.0,
                        hasSlashes: validatorInfo.slashed,
                        maxNominatorsRewarded: validatorInfo.stakeInfo?.maxNominatorsRewarded ?? 0,
                        blocked: false
                    )

                    self?.presenter.didReceiveValidatorInfo(result: .success(validator))
                } catch {
                    self?.presenter.didReceiveValidatorInfo(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }
}
