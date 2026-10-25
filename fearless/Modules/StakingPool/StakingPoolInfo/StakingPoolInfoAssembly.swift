import UIKit
import SoraFoundation
import SSFUtils
import SoraKeystore
import SSFModels

final class StakingPoolInfoAssembly {
    // swiftlint:disable function_body_length
    static func configureModule(
        poolId: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        status: NominationViewStatus?
    ) -> StakingPoolInfoModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager
        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )
        let stakingSettings = StakingAssetSettings(
            storageFacade: substrateStorageFacade,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            wallet: wallet
        )
        stakingSettings.setup()

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let settings = stakingSettings.value
        else {
            return nil
        }

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }
        eraValidatorService.setup()

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        guard let rewardService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: settings.assetDisplayInfo.assetPrecision,
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory
        ) else {
            return nil
        }

        rewardService.setup()

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }
        eraValidatorService.setup()

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardService,
            storageRequestFactory: storageOperationFactory,
            identityOperationFactory: identityOperationFactory,
            chainRegistry: chainRegistry
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

        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let interactor = StakingPoolInfoInteractor(
            chainAsset: chainAsset,
            operationManager: operationManager,
            runtimeService: runtimeService,
            validatorOperationFactory: validatorOperationFactory,
            poolId: poolId,
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            eraValidatorService: eraValidatorService
        )
        let router = StakingPoolInfoRouter()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )
        let viewModelFactory = StakingPoolInfoViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingPoolInfoPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            logger: logger,
            wallet: wallet,
            status: status,
            localizationManager: localizationManager
        )

        let view = StakingPoolInfoViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
