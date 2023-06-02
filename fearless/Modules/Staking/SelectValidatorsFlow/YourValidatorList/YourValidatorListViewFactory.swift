import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFUtils

struct YourValidatorListViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: YourValidatorListFlow
    ) -> YourValidatorListViewProtocol? {
        guard let container = createContainer(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return nil
        }

        let wireframe = YourValidatorListWireframe()

        let interactor = YourValidatorListInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: container.strategy
        )

        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared,
            viewModelState: container.viewModelState
        )

        let view = YourValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        flow: YourValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> YourValidatorListDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
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
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            wallet: wallet
        )

        stakingSettings.setup()

        let serviceFactory = StakingServiceFactory(
            chainRegisty: ChainRegistryFacade.sharedRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )

        guard let eraValidatorService = try? serviceFactory.createEraValidatorService(
            for: chainAsset.chain
        ) else {
            return nil
        }

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)
        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        guard let rewardCalculatorService = try? serviceFactory.createRewardCalculatorService(
            for: chainAsset,
            assetPrecision: Int16(chainAsset.asset.precision),
            validatorService: eraValidatorService,
            collatorOperationFactory: collatorOperationFactory,
            wallet: wallet
        ) else {
            return nil
        }

        defer {
            eraValidatorService.setup()
            rewardCalculatorService.setup()
        }

        let validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculatorService,
            storageRequestFactory: storageRequestFactory,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
            chainRegistry: chainRegistry
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

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        switch flow {
        case .relaychain:
            let viewModelState = YourValidatorListRelaychainViewModelState(chainAsset: chainAsset, wallet: wallet)
            let strategy = YourValidatorListRelaychainStrategy(
                chainAsset: chainAsset,
                wallet: wallet,
                substrateProviderFactory: substrateProviderFactory,
                runtimeService: runtimeService,
                eraValidatorService: eraValidatorService,
                validatorOperationFactory: validatorOperationFactory,
                operationManager: OperationManagerFacade.sharedManager,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountRepository: AnyDataProviderRepository(accountRepository),
                output: viewModelState
            )
            let viewModelFactory = YourValidatorListRelaychainViewModelFactory(
                balanceViewModeFactory: balanceViewModelFactory
            )

            return YourValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .pool:
            let stakingPoolOperationFactory = StakingPoolOperationFactory(
                chainAsset: chainAsset,
                storageRequestFactory: storageRequestFactory,
                chainRegistry: chainRegistry
            )
            let eraCountdownOperationFactory = EraCountdownOperationFactory(
                storageRequestFactory: storageRequestFactory
            )
            let viewModelState = YourValidatorListPoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet
            )

            let strategy = YourValidatorListPoolStrategy(
                stakingPoolOperationFactory: stakingPoolOperationFactory,
                chainAsset: chainAsset,
                wallet: wallet,
                eraValidatorService: eraValidatorService,
                operationManager: OperationManagerFacade.sharedManager,
                chainRegistry: chainRegistry,
                eraCountdownOperationFactory: eraCountdownOperationFactory,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                runtimeService: runtimeService,
                validatorOperationFactory: validatorOperationFactory,
                output: viewModelState
            )
            let viewModelFactory = YourValidatorListPoolViewModelFactory(
                balanceViewModeFactory: balanceViewModelFactory
            )
            return YourValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
