import UIKit
import SoraFoundation
import SoraKeystore
import FearlessUtils

final class StakingPoolMainAssembly {
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

        guard
            let chainAsset = stakingSettings.value else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let accountResponse = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

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

        guard let rewardCalculatorService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: Int16(chainAsset.asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: nil
        ) else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let interactor = StakingPoolMainInteractor(
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            selectedWalletSettings: SelectedWalletSettings.shared,
            settings: stakingSettings,
            stakingPoolOperationFactory: stakingPoolOperationFactory,
            rewardCalculationService: rewardCalculatorService,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset
        )

        let router = StakingPoolMainRouter()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )
        let presenter = StakingPoolMainPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            balanceViewModelFactory: balanceViewModelFactory,
            moduleOutput: moduleOutput
        )

        let view = StakingPoolMainViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
