import Foundation
import RobinHood

protocol StakingBalanceParachainStrategyOutput {}

final class StakingBalanceParachainStrategy {
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel
    private let operationFactory: ParachainCollatorOperationFactory
    private let operationManager: OperationManagerProtocol

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationFactory: ParachainCollatorOperationFactory,
        operationManager: OperationManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationFactory = operationFactory
        self.operationManager = operationManager
    }
}
