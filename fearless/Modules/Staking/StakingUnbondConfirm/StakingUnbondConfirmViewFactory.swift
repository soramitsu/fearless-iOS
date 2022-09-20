import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

struct StakingUnbondConfirmViewFactory: StakingUnbondConfirmViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondConfirmFlow
    ) -> StakingUnbondConfirmViewProtocol? {
        let wireframe = StakingUnbondConfirmWireframe()
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
        ) else {
            return nil
        }

        let presenter = createPresenter(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            wallet: wallet,
            container: container,
            dataValidatingFactory: dataValidatingFactory
        )

        let view = StakingUnbondConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        chainAsset: ChainAsset,
        interactor: StakingUnbondConfirmInteractorInputProtocol,
        wireframe: StakingUnbondConfirmWireframeProtocol,
        wallet: MetaAccountModel,
        container: StakingUnbondConfirmDependencyContainer,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> StakingUnbondConfirmPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
        )

        return StakingUnbondConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: container.viewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelState: container.viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset
        )
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingUnbondConfirmStrategy
    ) -> StakingUnbondConfirmInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        return StakingUnbondConfirmInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: strategy
        )
    }

    private static func createContainer(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingUnbondConfirmFlow,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> StakingUnbondConfirmDependencyContainer? {
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

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )

        switch flow {
        case let .relaychain(amount):
            let viewModelState = StakingUnbondConfirmRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                inputAmount: amount
            )
            let strategy = StakingUnbondConfirmRelaychainStrategy(
                output: viewModelState,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                runtimeService: runtimeService,
                operationManager: operationManager,
                feeProxy: feeProxy,
                chainAsset: chainAsset,
                wallet: wallet,
                connection: connection,
                keystore: Keychain(),
                accountRepository: AnyDataProviderRepository(accountRepository)
            )
            let viewModelFactory = StakingUnbondConfirmRelaychainViewModelFactory(
                asset: chainAsset.asset,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
            )
            return StakingUnbondConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(candidate, delegation, amount, revoke, bondingDuration):
            let viewModelState = StakingUnbondConfirmParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                inputAmount: amount,
                candidate: candidate,
                delegation: delegation,
                revoke: revoke
            )

            let strategy = StakingUnbondConfirmParachainStrategy(
                output: viewModelState,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                runtimeService: runtimeService,
                operationManager: operationManager,
                feeProxy: feeProxy,
                chainAsset: chainAsset,
                wallet: wallet,
                connection: connection,
                keystore: Keychain(),
                extrinsicService: extrinsicService,
                signingWrapper: signingWrapper,
                eventCenter: EventCenter.shared
            )

            let viewModelFactory = StakingUnbondConfirmParachainViewModelFactory(
                asset: chainAsset.asset,
                bondingDuration: bondingDuration,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
            )

            return StakingUnbondConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
