import Foundation
import FearlessUtils

final class EquilibriumTotalBalanceServiceFactory {
    static func createService(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> EquilibriumTotalBalanceServiceProtocol {
        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let keyFactory = StorageKeyFactory()
        let operationManager = OperationManagerFacade.sharedManager
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)

        let service = EquilibriumTotalBalanceService(
            wallet: wallet,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            equilibriumChainAsset: chainAsset,
            storageRequestFactory: storageRequestFactory,
            operationManager: operationManager,
            runtimeService: runtimeProvider,
            engine: connection,
            logger: Logger.shared
        )
        return service
    }
}
