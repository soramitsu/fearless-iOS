import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils
import SSFModels
import SSFAccountManagmentStorage

struct StakingBalanceViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBalanceFlow
    ) -> StakingBalanceViewProtocol? {
        let wireframe = StakingBalanceWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        guard let container = createContainer(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: dataValidatingFactory
        ) else {
            return nil
        }
        guard let interactor = createInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: container.strategy
        ) else { return nil }

        let presenter = StakingBalancePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            wallet: wallet
        )

        interactor.presenter = presenter

        let viewController = StakingBalanceViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = viewController
        dataValidatingFactory.view = viewController

        return viewController
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet _: MetaAccountModel,
        strategy: StakingBalanceStrategy
    ) -> StakingBalanceInteractor? {
        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared

        return StakingBalanceInteractor(
            chainAsset: chainAsset,
            priceLocalSubscriber: priceLocalSubscriber,
            strategy: strategy
        )
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        flow: StakingBalanceFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol
    ) -> StakingBalanceDependencyContainer? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let eraCountdownOperationFactory = EraCountdownOperationFactory(
            storageRequestFactory: storageRequestFactory
        )

        switch flow {
        case .relaychain:
            let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let viewModelState = StakingBalanceRelaychainViewModelState(
                countdownTimer: CountdownTimer(),
                dataValidatingFactory: dataValidatingFactory
            )
            let viewModelFactory = StakingBalanceRelaychainViewModelFactory(
                asset: chainAsset.asset,
                balanceViewModelFactory: balanceViewModelFactory,
                timeFormatter: TotalTimeFormatter()
            )

            let strategy = StakingBalanceRelaychainStrategy(
                output: viewModelState,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                runtimeCodingService: runtimeService,
                operationManager: operationManager,
                eraCountdownOperationFactory: eraCountdownOperationFactory,
                connection: connection,
                accountRepository: AnyDataProviderRepository(accountRepository),
                chainAsset: chainAsset,
                wallet: wallet
            )
            return StakingBalanceDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(delegation, candidate):
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
                logger: Logger.shared
            )

            let stakingAccountUpdatingService = StakingAccountUpdatingService(
                chainRegistry: chainRegistry,
                substrateRepositoryFactory: substrateRepositoryFactory,
                substrateDataProviderFactory: substrateDataProviderFactory,
                childSubscriptionFactory: childSubscriptionFactory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )

            let stakingLocalSubscriptionFactory = ParachainStakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

            let operationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageRequestFactory,
                identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory),
                subqueryOperationFactory: rewardOperationFactory,
                chainRegistry: chainRegistry
            )

            let subqueryHistoryOperationFactory = ParachainHistoryOperationFactoryAssembly.factory(
                blockExplorer: chainAsset.chain.externalApi?.staking
            )

            let viewModelState = StakingBalanceParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                collator: candidate,
                delegation: delegation
            )

            let strategy = StakingBalanceParachainStrategy(
                collator: candidate,
                chainAsset: chainAsset,
                wallet: wallet,
                operationFactory: operationFactory,
                operationManager: operationManager,
                output: viewModelState,
                parachainStakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                logger: Logger.shared,
                stakingAccountUpdatingService: stakingAccountUpdatingService,
                subqueryHistoryOperationFactory: subqueryHistoryOperationFactory
            )

            let viewModelFactory = StakingBalanceParachainViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory,
                timeFormatter: TotalTimeFormatter()
            )

            return StakingBalanceDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
