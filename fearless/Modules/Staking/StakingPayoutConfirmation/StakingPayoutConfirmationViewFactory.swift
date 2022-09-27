import Foundation
import SoraFoundation
import SoraKeystore
import FearlessUtils
import RobinHood

final class StakingPayoutConfirmationViewFactory: StakingPayoutConfirmationViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingPayoutConfirmationFlow
    ) -> StakingPayoutConfirmationViewProtocol? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
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
            viewModelState: container.viewModelState
        )

        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        guard let interactor = createInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: container.strategy
        ) else {
            return nil
        }

        dataValidationFactory.view = view
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        strategy: StakingPayoutConfirmationStrategy
    ) -> StakingPayoutConfirmationInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        return StakingPayoutConfirmationInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            wallet: wallet,
            chainAsset: chainAsset,
            strategy: strategy
        )
    }

    // swiftlint: disable function_body_length
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

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
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
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
        )

        let feeProxy = ExtrinsicFeeProxy()

        switch flow {
        case let .relaychain(payouts):
            let viewModelState = StakingPayoutConfirmationRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                logger: logger,
                dataValidatingFactory: dataValidatingFactory
            )

            let viewModelFactory = StakingPayoutConfirmationRelaychainViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
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
                output: viewModelState
            )

            return StakingPayoutConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .pool:
            let viewModelState = StakingPayoutConfirmationPoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                logger: logger,
                dataValidatingFactory: dataValidatingFactory
            )

            let viewModelFactory = StakingPayoutConfirmationPoolViewModelFactory(
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
            )

            let strategy = StakingPayoutConfirmationPoolStrategy(
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
