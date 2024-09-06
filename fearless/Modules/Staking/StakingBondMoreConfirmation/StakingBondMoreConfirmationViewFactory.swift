import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFModels
import SSFUtils
import SSFAccountManagmentStorage

struct StakingBondMoreConfirmViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingBondMoreConfirmationFlow
    ) -> StakingBondMoreConfirmationViewProtocol? {
        let wireframe = StakingBondMoreConfirmationWireframe()
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
            strategy: container.strategy
        ) else {
            return nil
        }

        let presenter = createPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
            from: interactor,
            viewModelState: container.viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            wireframe: wireframe,
            flow: flow
        )

        let view = StakingBondMoreConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createPresenter(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from interactor: StakingBondMoreConfirmationInteractorInputProtocol,
        viewModelState: StakingBondMoreConfirmationViewModelState,
        dataValidatingFactory: StakingDataValidatingFactory,
        wireframe: StakingBondMoreConfirmationWireframe,
        flow: StakingBondMoreConfirmationFlow
    ) -> StakingBondMoreConfirmationPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )

        var confirmationViewModelFactory: StakingBondMoreConfirmViewModelFactoryProtocol
        switch flow {
        case .relaychain:
            confirmationViewModelFactory = StakingBondMoreConfirmRelaychainViewModelFactory(
                chainAsset: chainAsset,
                iconGenerator: UniversalIconGenerator(),
                balanceViewModelFactory: balanceViewModelFactory
            )
        case .parachain:
            confirmationViewModelFactory = StakingBondMoreConfirmParachainViewModelFactory(
                chainAsset: chainAsset,
                iconGenerator: UniversalIconGenerator(),
                balanceViewModelFactory: balanceViewModelFactory
            )
        case .pool:
            confirmationViewModelFactory = StakingBondMoreConfirmPoolViewModelFactory(
                chainAsset: chainAsset,
                iconGenerator: UniversalIconGenerator(),
                balanceViewModelFactory: balanceViewModelFactory
            )
        }

        return StakingBondMoreConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelState: viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingBondMoreConfirmationStrategy
    ) -> StakingBondMoreConfirmationInteractor? {
        StakingBondMoreConfirmationInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: strategy
        )
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        flow: StakingBondMoreConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> StakingBondMoreConfirmationDependencyContainer? {
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

        let feeProxy = ExtrinsicFeeProxy()

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            operationManager: operationManager,
            chainRegistry: chainRegistry,
            logger: logger
        )

        let keystore = Keychain()
        let signingWrapper = SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            selectedMetaAccount: wallet
        )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        switch flow {
        case let .relaychain(amount):
            let viewModelState = StakingBondMoreConfirmationRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                amount: amount,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = StakingBondMoreConfirmationRelaychainStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                accountRepository: AnyDataProviderRepository(accountRepository),
                connection: connection,
                keystore: keystore,
                signingWrapper: signingWrapper,
                output: viewModelState,
                callFactory: callFactory
            )

            return StakingBondMoreConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy
            )
        case let .parachain(amount, candidate):
            let viewModelState = StakingBondMoreConfirmationParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                amount: amount,
                dataValidatingFactory: dataValidatingFactory,
                candidate: candidate,
                callFactory: callFactory
            )

            let strategy = StakingBondMoreConfirmationParachainStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                connection: connection,
                keystore: keystore,
                signingWrapper: signingWrapper,
                output: viewModelState,
                eventCenter: EventCenter.shared,
                logger: Logger.shared,
                callFactory: callFactory
            )

            return StakingBondMoreConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy
            )
        case let .pool(amount):
            let viewModelState = StakingBondMoreConfirmationPoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                amount: amount,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )

            let strategy = StakingBondMoreConfirmationPoolStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                operationManager: operationManager,
                connection: connection,
                keystore: keystore,
                signingWrapper: signingWrapper,
                output: viewModelState,
                eventCenter: EventCenter.shared,
                logger: Logger.shared,
                callFactory: callFactory
            )

            return StakingBondMoreConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy
            )
        }
    }
}
