import UIKit
import SoraFoundation
import FearlessUtils

final class StakingPoolManagementAssembly {
    static func configureModule(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> StakingPoolManagementModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }
        eraValidatorService.setup()

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

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            logger: logger
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            selectedMetaAccount: wallet
        )

        let stakingDurationOperationFactory = StakingDurationOperationFactory()

        let accountOperationFactory = AccountOperationFactory(
            engine: connection,
            requestFactory: requestFactory,
            runtimeService: runtimeService
        )

        let existentialDepositService = ExistentialDepositService(
            runtimeCodingService: runtimeService,
            operationManager: operationManager,
            engine: connection
        )

        let interactor = StakingPoolManagementInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            eraValidatorService: eraValidatorService,
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            stakingDurationOperationFactory: stakingDurationOperationFactory,
            runtimeService: runtimeService,
            accountOperationFactory: accountOperationFactory,
            existentialDepositService: existentialDepositService
        )
        let router = StakingPoolManagementRouter()

        let viewModelFactory = StakingPoolManagementViewModelFactory(chainAsset: chainAsset)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        let presenter = StakingPoolManagementPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            chainAsset: chainAsset,
            wallet: wallet, viewModelFactory: viewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            rewardCalculator: StakinkPoolRewardCalculator(),
            logger: logger
        )

        let view = StakingPoolManagementViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
