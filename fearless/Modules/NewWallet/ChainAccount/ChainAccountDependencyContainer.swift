import Foundation
import FearlessUtils

struct ChainAccountDependencies {
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let existentialDepositService: ExistentialDepositServiceProtocol
}

final class ChainAccountDependencyContainer {
    func prepareDepencies(
        chainAsset: ChainAsset
    ) -> BalanceInfoDependencies? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else {
            return nil
        }
        let operationManager = OperationManagerFacade.sharedManager
        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )
        return BalanceInfoDependencies(
            connection: connection,
            runtimeService: runtimeService,
            existentialDepositService: existentialDepositService
        )
    }
}
