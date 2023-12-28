import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils
import SSFModels

struct StakingRewardDestSetupViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    ) -> StakingRewardDestSetupViewProtocol? {
        guard let interactor = try? createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            rewardChainAsset: rewardChainAsset
        ) else {
            return nil
        }

        let wireframe = StakingRewardDestSetupWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,

            selectedMetaAccount: selectedAccount
        )

        let rewardAsset = rewardChainAsset?.asset ?? asset
        let rewardBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: rewardAsset.displayInfo,
            selectedMetaAccount: selectedAccount
        )

        let rewardDestinationViewModelFactory = RewardDestinationViewModelFactory(
            balanceViewModelFactory: rewardBalanceViewModelFactory,
            iconGenerator: UniversalIconGenerator(),
            chainAsset: ChainAsset(chain: chain, asset: asset)
        )

        let changeRewardDestViewModelFactory = ChangeRewardDestinationViewModelFactory(
            rewardDestinationViewModelFactory: rewardDestinationViewModelFactory
        )

        let presenter = StakingRewardDestSetupPresenter(
            wireframe: wireframe,
            interactor: interactor,
            rewardDestViewModelFactory: changeRewardDestViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            applicationConfig: ApplicationConfig.shared,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            logger: Logger.shared
        )

        let view = StakingRewardDestSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        rewardChainAsset: ChainAsset?
    ) throws -> StakingRewardDestSetupInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId)
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: operationManager
        )

        let feeProxy = ExtrinsicFeeProxy()
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let facade = UserDataStorageFacade.shared
        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let stakingSettings = StakingAssetSettings(
            storageFacade: substrateStorageFacade,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            wallet: selectedAccount
        )

        stakingSettings.setup()

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: substrateStorageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard let settings = stakingSettings.value else {
            return nil
        }

        let eraValidatorService = try serviceFactory.createEraValidatorService(
            for: settings.chain
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: asset,
            chain: chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        let rewardCalculatorService = try serviceFactory.createRewardCalculatorService(
            for: ChainAsset(chain: settings.chain, asset: settings.asset),
            assetPrecision: settings.assetDisplayInfo.assetPrecision,
            validatorService: eraValidatorService, collatorOperationFactory: collatorOperationFactory
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        return StakingRewardDestSetupInteractor(
            accountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedAccount
            ),
            substrateProviderFactory: substrateProviderFactory,
            calculatorService: rewardCalculatorService,
            runtimeService: runtimeService,
            operationManager: operationManager,
            feeProxy: feeProxy,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            connection: connection,
            callFactory: callFactory,
            rewardChainAsset: rewardChainAsset
        )
    }
}
