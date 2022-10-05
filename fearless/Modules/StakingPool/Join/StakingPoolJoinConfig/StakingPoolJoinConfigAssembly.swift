import UIKit
import SoraFoundation
import RobinHood
import FearlessUtils

// swiftlint:disable function_body_length
final class StakingPoolJoinConfigAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        amount: Decimal?
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
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            logger: logger
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            selectedMetaAccount: wallet
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: requestFactory,
            runtimeService: runtimeService,
            engine: connection
        )

        let localizationManager = LocalizationManager.shared

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )

        let interactor = StakingPoolJoinConfigInteractor(
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            operationManager: operationManager,
            existentialDepositService: existentialDepositService
        )
        let router = StakingPoolJoinConfigRouter()

        let iconGenerator = UniversalIconGenerator(chain: chainAsset.chain)
        let accountViewModelFactory = AccountViewModelFactory(iconGenerator: iconGenerator)
        let assetInfo = chainAsset.asset.displayInfo(with: chainAsset.chain.icon)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: router,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StakingPoolJoinConfigPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            balanceViewModelFactory: balanceViewModelFactory,
            accountViewModelFactory: accountViewModelFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            logger: Logger.shared,
            dataValidatingFactory: dataValidatingFactory,
            amount: amount
        )

        let view = StakingPoolJoinConfigViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        dataValidatingFactory.view = view

        return (view, presenter)
    }
}
