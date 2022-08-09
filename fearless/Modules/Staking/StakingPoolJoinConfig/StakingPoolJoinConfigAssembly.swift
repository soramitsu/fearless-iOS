import UIKit
import SoraFoundation
import RobinHood

final class StakingPoolJoinConfigAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> StakingPoolJoinConfigModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            selectedMetaAccount: wallet
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        let localizationManager = LocalizationManager.shared

        let interactor = StakingPoolJoinConfigInteractor(
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy
        )
        let router = StakingPoolJoinConfigRouter()

        let iconGenerator = UniversalIconGenerator(chain: chainAsset.chain)
        let accountViewModelFactory = AccountViewModelFactory(iconGenerator: iconGenerator)
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        let presenter = StakingPoolJoinConfigPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            balanceViewModelFactory: balanceViewModelFactory,
            accountViewModelFactory: accountViewModelFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            logger: Logger.shared
        )

        let view = StakingPoolJoinConfigViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
