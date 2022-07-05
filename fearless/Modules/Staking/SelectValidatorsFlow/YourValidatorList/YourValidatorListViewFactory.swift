import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore
import FearlessUtils

struct YourValidatorListViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> YourValidatorListViewProtocol? {
        guard let interactor = try? createInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount
        ) else {
            return nil
        }

        let wireframe = YourValidatorListWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: selectedAccount
        )

        let viewModelFactory = YourValidatorListViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory,
            iconGenerator: UniversalIconGenerator(chain: chain)
        )

        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = YourValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) throws -> YourValidatorListInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let substrateProviderFactory = SubstrateDataProviderFactory(
            facade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingSettings = StakingAssetSettings(
            storageFacade: storageFacade,
            settings: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        stakingSettings.setup()

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        let eraValidatorService = try serviceFactory.createEraValidatorService(
            for: chain
        )

        let subqueryRewardOperationFactory = SubqueryRewardOperationFactory(url: chain.externalApi?.staking?.url)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: asset,
            chain: chain,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: subqueryRewardOperationFactory
        )

        let rewardCalculatorService = try serviceFactory.createRewardCalculatorService(
            for: ChainAsset(chain: chain, asset: asset),
            assetPrecision: Int16(asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory
        )

        defer {
            eraValidatorService.setup()
            rewardCalculatorService.setup()
        }

        let validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: asset,
            chain: chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculatorService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        return YourValidatorListInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            substrateProviderFactory: substrateProviderFactory,
            runtimeService: runtimeService,
            eraValidatorService: eraValidatorService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: OperationManagerFacade.sharedManager,
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            accountRepository: AnyDataProviderRepository(accountRepository)
        )
    }
}
