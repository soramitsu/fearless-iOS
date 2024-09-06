import Foundation
import SoraFoundation
import SoraKeystore
import SSFUtils
import RobinHood
import SSFModels
import SSFAccountManagmentStorage

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingPayoutConfirmationFlow
    ) -> StakingPayoutConfirmationViewProtocol? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.chain.utilityChainAssets().first?.asset.displayInfo ?? chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )

        let wireframe = StakingPayoutConfirmationWireframe()

        let dataValidationFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        guard let container = createDependencyContainer(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            dataValidatingFactory: dataValidationFactory
        ) else {
            return nil
        }

        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory,
            payoutConfirmViewModelFactory: container.viewModelFactory,
            dataValidatingFactory: dataValidationFactory,
            chainAsset: chainAsset,
            logger: Logger.shared,
            viewModelState: container.viewModelState,
            wallet: wallet
        )

        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let interactor = StakingPayoutConfirmationInteractor(
            strategy: container.strategy
        )

        dataValidationFactory.view = view
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable function_body_length
    private static func createDependencyContainer(
        flow: StakingPayoutConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> StakingPayoutConfirmationDependencyContainer? {
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

        let extrinsicOperationFactory = ExtrinsicOperationFactory(
            accountId: accountResponse.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
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
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )

        let feeProxy = ExtrinsicFeeProxy()

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        switch flow {
        case let .relaychain(payouts):
            let viewModelState = StakingPayoutConfirmationRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                logger: logger,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )

            let viewModelFactory = StakingPayoutConfirmationRelaychainViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator()
            )

            let strategy = StakingPayoutConfirmationRelayachainStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                extrinsicService: extrinsicService,
                extrinsicOperationFactory: extrinsicOperationFactory,
                runtimeService: runtimeService,
                signer: signingWrapper,
                operationManager: operationManager,
                logger: logger,
                wallet: wallet,
                payouts: payouts,
                chainAsset: chainAsset,
                accountRepository: AnyDataProviderRepository(accountRepository),
                output: viewModelState,
                callFactory: callFactory
            )

            return StakingPayoutConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .pool(rewardAmount):
            let viewModelState = StakingPayoutConfirmationPoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                logger: logger,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )

            let viewModelFactory = StakingPayoutConfirmationPoolViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator()
            )

            let strategy = StakingPayoutConfirmationPoolStrategy(
                rewardAmount: rewardAmount,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                extrinsicService: extrinsicService,
                extrinsicOperationFactory: extrinsicOperationFactory,
                runtimeService: runtimeService,
                signer: signingWrapper,
                operationManager: operationManager,
                logger: logger,
                wallet: wallet,
                chainAsset: chainAsset,
                output: viewModelState,
                feeProxy: feeProxy
            )

            return StakingPayoutConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
