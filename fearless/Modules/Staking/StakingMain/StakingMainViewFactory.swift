import Foundation
import SoraFoundation
import SSFUtils
import SoraKeystore
import SSFModels
import RobinHood

// swiftlint:disable function_body_length
final class StakingMainViewFactory: StakingMainViewFactoryProtocol {
    static func createView(moduleOutput: StakingMainModuleOutput?) -> StakingMainViewProtocol? {
        guard let selectedAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        let settings = SettingsManager.shared

        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingSettings = StakingAssetSettings(
            storageFacade: storageFacade,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            wallet: selectedAccount
        )

        stakingSettings.setup()

        guard
            let chainAsset = stakingSettings.value,
            let sharedState = try? createSharedState(
                with: chainAsset,
                stakingSettings: stakingSettings,
                wallet: selectedAccount
            ) else {
            return nil
        }

        // MARK: - View

        let view = StakingMainViewController(nib: R.nib.stakingMainViewController)
        view.localizationManager = LocalizationManager.shared
        view.iconGenerator = UniversalIconGenerator()
        view.uiFactory = UIFactory()
        view.amountFormatterFactory = AssetBalanceFormatterFactory()

        // MARK: - Interactor

        let interactor = createInteractor(
            state: sharedState,
            settings: settings,
            selectedAccount: selectedAccount,
            chainAsset: chainAsset
        )

        // MARK: - Router

        let wireframe = StakingMainWireframe()

        // MARK: - Presenter

        let eventCenter = EventCenter.shared
        let viewModelFacade = StakingViewModelFacade(
            selectedMetaAccount: selectedAccount
        )
        let analyticsVMFactoryBuilder: AnalyticsRewardsViewModelFactoryBuilder
            = { chainAsset, balanceViewModelFactory in
                AnalyticsRewardsViewModelFactory(
                    assetInfo: chainAsset.assetDisplayInfo,
                    balanceViewModelFactory: balanceViewModelFactory,
                    calendar: Calendar(identifier: .gregorian)
                )
            }

        let logger = Logger.shared

        let stateViewModelFactory = StakingStateViewModelFactory(
            analyticsRewardsViewModelFactoryBuilder: analyticsVMFactoryBuilder,
            logger: logger,
            selectedMetaAccount: selectedAccount,
            eventCenter: eventCenter
        )
        let networkInfoViewModelFactory = NetworkInfoViewModelFactory()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingMainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            logger: logger,
            selectedMetaAccount: selectedAccount,
            moduleOutput: moduleOutput
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        state: StakingSharedState,
        settings: SettingsManagerProtocol,
        selectedAccount: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> StakingMainInteractor {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let chainItemRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let stakingRemoteSubscriptionService = StakingRemoteSubscriptionService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repository: chainItemRepository,
            operationManager: operationManager,
            logger: logger
        )

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
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

        let stakingAccountUpdatingService = StakingAccountUpdatingService(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            substrateRepositoryFactory: substrateRepositoryFactory,
            substrateDataProviderFactory: substrateDataProviderFactory,
            childSubscriptionFactory: childSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: selectedAccount
        )

        return StakingMainInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            sharedState: state,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            stakingRemoteSubscriptionService: stakingRemoteSubscriptionService,
            stakingAccountUpdatingService: stakingAccountUpdatingService,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            stakingServiceFactory: serviceFactory,
            accountProviderFactory: accountProviderFactory,
            eventCenter: EventCenter.shared,
            operationManager: operationManager,
            applicationHandler: ApplicationHandler(),
            eraCountdownOperationFactory: eraCountdownOperationFactory,
            commonSettings: settings,
            logger: logger,
            collatorOperationFactory: collatorOperationFactory,
            chainAssetFetching: chainAssetFetching
        )
    }

    private static func createSharedState(
        with chainAsset: ChainAsset,
        stakingSettings: StakingAssetSettings,
        wallet: MetaAccountModel
    ) throws -> StakingSharedState {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let storageFacade = SubstrateDataStorageFacade.shared
        let serviceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let eraValidatorService = try serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        let rewardCalculatorService = try serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: chainAsset.assetDisplayInfo.assetPrecision,
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory,
            wallet: wallet
        )

        let relaychainStakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let parachainStakingLocalSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let stakingAnalyticsLocalSubscriptionFactory = ParachainAnalyticsLocalSubscriptionFactory(
            storageFacade: storageFacade
        )

        return StakingSharedState(
            settings: stakingSettings,
            eraValidatorService: eraValidatorService,
            rewardCalculationService: rewardCalculatorService,
            relaychainStakingLocalSubscriptionFactory: relaychainStakingLocalSubscriptionFactory,
            stakingAnalyticsLocalSubscriptionFactory: stakingAnalyticsLocalSubscriptionFactory,
            parachainStakingLocalSubscriptionFactory: parachainStakingLocalSubscriptionFactory
        )
    }
}
