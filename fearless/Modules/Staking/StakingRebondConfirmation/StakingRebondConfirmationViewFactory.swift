import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils
import SSFModels

struct StakingRebondConfirmationViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRebondConfirmationFlow
    )
        -> StakingRebondConfirmationViewProtocol? {
        let wireframe = StakingRebondConfirmationWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
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
            container: container
        ) else {
            return nil
        }

        let presenter = createPresenter(
            chainAsset: chainAsset,
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            container: container
        )

        let view = StakingRebondConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    // swiftlint:disable function_parameter_count
    private static func createPresenter(
        chainAsset: ChainAsset,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        container: StakingRebondConfirmationDependencyContainer
    ) -> StakingRebondConfirmationPresenter {
        StakingRebondConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: container.viewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            viewModelState: container.viewModelState,
            logger: Logger.shared
        )
    }

    // swiftlint:disable function_body_length
    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        container: StakingRebondConfirmationDependencyContainer
    ) -> StakingRebondConfirmationInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        return StakingRebondConfirmationInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: container.strategy
        )
    }

    private static func createContainer(
        flow: StakingRebondConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol
    ) -> StakingRebondConfirmationDependencyContainer? {
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

        let keystore = Keychain()
        let feeProxy = ExtrinsicFeeProxy()
        let facade = UserDataStorageFacade.shared
        let mapper = MetaAccountMapper()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: accountResponse.walletId,
            accountResponse: accountResponse
        )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        switch flow {
        case let .relaychain(variant):
            let viewModelState = StakingRebondConfirmationRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                logger: logger,
                variant: variant,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let viewModelFactory = StakingRebondConfirmationRelaychainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                chainAsset: chainAsset,
                iconGenerator: UniversalIconGenerator()
            )
            let strategy = StakingRebondConfirmationRelaychainStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                keystore: keystore,
                connection: connection,
                accountRepository: AnyDataProviderRepository(accountRepository),
                output: viewModelState,
                callFactory: callFactory
            )

            return StakingRebondConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(delegationInfo, request):
            let viewModelState = StakingRebondConfirmationParachainViewModelState(
                delegation: delegationInfo,
                request: request,
                wallet: wallet,
                chainAsset: chainAsset,
                dataValidatingFactory: dataValidatingFactory,
                logger: logger,
                callFactory: callFactory
            )
            let viewModelFactory = StakingRebondConfirmationParachainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                chainAsset: chainAsset,
                wallet: wallet,
                iconGenerator: UniversalIconGenerator()
            )
            let strategy = StakingRebondConfirmationParachainStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                keystore: keystore,
                connection: connection,
                accountRepository: AnyDataProviderRepository(accountRepository),
                output: viewModelState,
                signingWrapper: signingWrapper
            )
            return StakingRebondConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
