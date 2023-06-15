import Foundation
import RobinHood
import SSFModels

protocol ValidatorInfoRelaychainStrategyOutput: AnyObject {
    func didReceiveValidatorInfo(_ validatorInfo: ValidatorInfoProtocol)
    func didReceiveError(_ error: Error)
    func didStartLoading()
}

final class ValidatorInfoRelaychainStrategy {
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let accountAddress: AccountAddress?
    private let validatorInfo: ValidatorInfoProtocol?
    private weak var output: ValidatorInfoRelaychainStrategyOutput?

    init(
        validatorInfo: ValidatorInfoProtocol?,
        accountAddress: AccountAddress?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        output: ValidatorInfoRelaychainStrategyOutput?
    ) {
        self.validatorInfo = validatorInfo
        self.accountAddress = accountAddress
        self.wallet = wallet
        self.chainAsset = chainAsset
        self.validatorOperationFactory = validatorOperationFactory
        self.operationManager = operationManager
        self.output = output
    }

    private func fetchValidatorInfo() {
        if let validatorInfo = validatorInfo {
            output?.didReceiveValidatorInfo(validatorInfo)
            return
        }

        do {
            guard let accountAddress = accountAddress,
                  let accountId = try? AddressFactory.accountId(from: accountAddress, chain: chainAsset.chain) else {
                throw (ChainAccountFetchingError.accountNotExists)
            }

            output?.didStartLoading()

            let operation = validatorOperationFactory.wannabeValidatorsOperation(for: [accountId])

            operation.targetOperation.completionBlock = { [weak self] in
                guard let self = self else {
                    return
                }
                DispatchQueue.main.async {
                    do {
                        if let validatorInfo =
                            try operation.targetOperation.extractNoCancellableResultData().first {
                            self.output?.didReceiveValidatorInfo(validatorInfo)
                        } else {
                            let validatorInfo = SelectedValidatorInfo(address: accountAddress)
                            self.output?.didReceiveValidatorInfo(validatorInfo)
                        }
                    } catch {
                        self.output?.didReceiveError(error)
                    }
                }
            }

            operationManager.enqueue(operations: operation.allOperations, in: .transient)
        } catch {
            output?.didReceiveError(error)
        }
    }
}

extension ValidatorInfoRelaychainStrategy: ValidatorInfoStrategy {
    func setup() {
        fetchValidatorInfo()
    }

    func reload() {
        fetchValidatorInfo()
    }
}
