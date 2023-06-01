import FearlessUtils

struct BalanceInfoDependencies {
    let connection: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let existentialDepositService: ExistentialDepositServiceProtocol
}

final class BalanceInfoDepencyContainer {
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
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )
        return BalanceInfoDependencies(
            connection: connection,
            runtimeService: runtimeService,
            existentialDepositService: existentialDepositService
        )
    }
}
