import UIKit
import SoraFoundation
import SoraKeystore
import SSFUtils

final class StakingPoolMainAssembly {
    // swiftlint:disable function_body_length
    static func configureModule(moduleOutput: StakingMainModuleOutput?) -> StakingPoolMainModuleCreationResult? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingSettings = StakingAssetSettings(
            storageFacade: storageFacade,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            wallet: wallet
        )

        stakingSettings.setup()

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let chainAsset = stakingSettings.value
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

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

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: requestFactory,
            chainRegistry: chainRegistry
        )

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

        guard let rewardCalculatorService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: Int16(chainAsset.asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: nil
        ) else {
            return nil
        }
        rewardCalculatorService.setup()

        let localizationManager = LocalizationManager.shared
        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let substrateDataProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let childSubscriptionFactory = ChildSubscriptionFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager,
            eventCenter: EventCenter.shared,
            logger: logger
        )

        let poolStakingAccountUpdatingService = PoolStakingAccountUpdatingService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            substrateRepositoryFactory: substrateRepositoryFactory,
            substrateDataProviderFactory: substrateDataProviderFactory,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let stakingAccountUpdatingService = StakingAccountUpdatingService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            substrateRepositoryFactory: substrateRepositoryFactory,
            substrateDataProviderFactory: substrateDataProviderFactory,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }
        eraValidatorService.setup()

        let accountOperationFactory = AccountOperationFactory(
            requestFactory: requestFactory,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: identityOperationFactory,
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        guard let rewardService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: Int16(chainAsset.asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory
        ) else {
            return nil
        }

        rewardService.setup()

        let validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardService,
            storageRequestFactory: storageOperationFactory,
            identityOperationFactory: identityOperationFactory,
            chainRegistry: chainRegistry
        )

        let chainItemRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let stakingRemoteSubscriptionService = StakingRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: chainItemRepository,
            operationManager: operationManager,
            logger: logger
        )

        let interactor = StakingPoolMainInteractor(
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            selectedWalletSettings: SelectedWalletSettings.shared,
            settings: stakingSettings,
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            rewardCalculationService: rewardCalculatorService,
            chainAsset: chainAsset,
            wallet: wallet,
            operationManager: OperationManagerFacade.sharedManager,
            stakingServiceFactory: serviceFactory,
            logger: Logger.shared,
            commonSettings: SettingsManager.shared,
            eraValidatorService: eraValidatorService,
            chainRegistry: chainRegistry,
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            eventCenter: EventCenter.shared,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            poolStakingAccountUpdatingService: poolStakingAccountUpdatingService,
            accountOperationFactory: accountOperationFactory,
            existentialDepositService: existentialDepositService,
            validatorOperationFactory: validatorOperationFactory,
            stakingAccountUpdatingService: stakingAccountUpdatingService,
            stakingRemoteSubscriptionService: stakingRemoteSubscriptionService
        )

        let router = StakingPoolMainRouter()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        let viewModelFactory = StakingPoolMainViewModelFactory(wallet: wallet)
        let presenter = StakingPoolMainPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            balanceViewModelFactory: balanceViewModelFactory,
            moduleOutput: moduleOutput,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: logger
        )

        let view = StakingPoolMainViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
