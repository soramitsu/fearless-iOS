import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct StakingUnbondSetupViewFactory: StakingUnbondSetupViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondSetupFlow
    ) -> StakingUnbondSetupViewProtocol? {
        let wireframe = StakingUnbondSetupWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        guard let container = createContainer(
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: dataValidatingFactory,
            flow: flow
        ),
            let interactor = createInteractor(
                chainAsset: chainAsset,
                wallet: wallet,
                strategy: container.strategy
            ) else {
            return nil
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet
        )

        let presenter = StakingUnbondSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            chainAsset: chainAsset,
            wallet: wallet
        )

        let view = StakingUnbondSetupViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingUnbondSetupStrategy
    ) -> StakingUnbondSetupInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        return StakingUnbondSetupInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            strategy: strategy
        )
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory,
        flow: StakingUnbondSetupFlow
    ) -> StakingUnbondSetupDependencyContainer? {
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

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let feeProxy = ExtrinsicFeeProxy()
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
        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)
        let stakingDurationOperationFactory = StakingDurationOperationFactory()

        switch flow {
        case .relaychain:
            let viewModelState = StakingUnbondSetupRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory
            )
            let strategy = StakingUnbondSetupRelaychainStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                runtimeService: runtimeService,
                operationManager: operationManager,
                feeProxy: feeProxy,
                wallet: wallet,
                chainAsset: chainAsset,
                connection: connection,
                accountRepository: AnyDataProviderRepository(accountRepository),
                output: viewModelState,
                extrinsicService: extrinsicService
            )
            let viewModelFactory = StakingUnbondSetupRelaychainViewModelFactory()

            return StakingUnbondSetupDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(candidate, delegation):
            let rewardOperationFactory = RewardOperationFactory.factory(blockExplorer: chainAsset.chain.externalApi?.staking)

            let operationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageOperationFactory,
                runtimeService: runtimeService,
                engine: connection,
                identityOperationFactory: identityOperationFactory,
                subqueryOperationFactory: rewardOperationFactory
            )
            let viewModelState = StakingUnbondSetupParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                candidate: candidate,
                delegation: delegation
            )
            let strategy = StakingUnbondSetupParachainStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                runtimeService: runtimeService,
                operationManager: operationManager,
                feeProxy: feeProxy,
                wallet: wallet,
                chainAsset: chainAsset,
                connection: connection,
                output: viewModelState,
                extrinsicService: extrinsicService,
                operationFactory: operationFactory,
                candidate: candidate,
                delegation: delegation
            )
            let viewModelFactory = StakingUnbondSetupParachainViewModelFactory(
                accountViewModelFactory:
                AccountViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            )
            return StakingUnbondSetupDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )

        case .pool:
            let viewModelState = StakingUnbondSetupPoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory
            )
            let viewModelFactory = StakingUnbondSetupPoolViewModelFactory(
                accountViewModelFactory: AccountViewModelFactory(iconGenerator: UniversalIconGenerator(chain: chainAsset.chain))
            )
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
            let strategy = StakingUnbondSetupPoolStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                operationManager: operationManager,
                feeProxy: feeProxy,
                wallet: wallet,
                chainAsset: chainAsset,
                output: viewModelState,
                extrinsicService: extrinsicService,
                stakingPoolOperationFactory: stakingPoolOperationFactory,
                stakingDurationOperationFactory: stakingDurationOperationFactory,
                runtimeService: runtimeService
            )

            return StakingUnbondSetupDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
