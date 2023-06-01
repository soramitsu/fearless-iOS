import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils
import CommonWallet

struct StakingBondMoreViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreFlow
    ) -> StakingBondMoreViewProtocol? {
        let wireframe = StakingBondMoreWireframe()
        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        guard let container = createContainer(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            dataValidatingFactory: dataValidatingFactory
        ) else {
            return nil
        }

        guard let interactor = createInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: container.strategy
        ) else { return nil }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            networkFeeViewModelFactory: NetworkFeeViewModelFactory(),
            chainAsset: chainAsset,
            wallet: wallet
        )
        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = viewController
        interactor.presenter = presenter
        dataValidatingFactory.view = viewController

        return viewController
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingBondMoreStrategy
    ) -> StakingBondMoreInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        let interactor = StakingBondMoreInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,

            strategy: strategy
        )

        return interactor
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreFlow,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> StakingBondMoreDependencyContainer? {
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

        let existentialDepositService = ExistentialDepositService(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            chainId: chainAsset.chain.chainId
        )

        let feeProxy = ExtrinsicFeeProxy()

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

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

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        switch flow {
        case .relaychain:
            let viewModelState = StakingBondMoreRelaychainViewModelState(
                chainAsset: chainAsset,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )

            let strategy = StakingBondMoreRelaychainStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                output: viewModelState,
                chainAsset: chainAsset,
                wallet: wallet,
                accountRepository: AnyDataProviderRepository(accountRepository),
                connection: connection,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                callFactory: callFactory,
                existentialDepositService: existentialDepositService
            )
            let viewModelFactory = StakingBondMoreRelaychainViewModelFactory(
                accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            )
            return StakingBondMoreDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(candidate):
            let viewModelState = StakingBondMoreParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                candidate: candidate,
                callFactory: callFactory
            )
            let strategy = StakingBondMoreParachainStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                output: viewModelState,
                chainAsset: chainAsset,
                wallet: wallet,
                connection: connection,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                callFactory: callFactory,
                existentialDepositService: existentialDepositService
            )

            let viewModelFactory = StakingBondMoreParachainViewModelFactory(
                accountViewModelFactory:
                AccountViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            )

            return StakingBondMoreDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .pool:
            let viewModelState = StakingBondMorePoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = StakingBondMorePoolStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                output: viewModelState,
                chainAsset: chainAsset,
                wallet: wallet,
                connection: connection,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                callFactory: callFactory,
                existentialDepositService: existentialDepositService
            )
            let viewModelFactory = StakingBondMorePoolViewModelFactory(
                accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            )

            return StakingBondMoreDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
