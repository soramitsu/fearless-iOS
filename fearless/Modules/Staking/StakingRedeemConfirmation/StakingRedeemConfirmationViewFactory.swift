import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import SSFUtils

final class StakingRedeemConfirmationViewFactory: StakingRedeemConfirmationViewFactoryProtocol {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow,
        redeemCompletion: (() -> Void)?
    ) -> StakingRedeemConfirmationViewProtocol? {
        let wireframe = StakingRedeemConfirmationWireframe(redeemCompletion: redeemCompletion)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        guard let container = createContainer(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            dataValidatingFactory: dataValidatingFactory
        ), let interactor = createInteractor(
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
            wallet: wallet,
            container: container
        )

        let view = StakingRedeemConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createPresenter(
        chainAsset: ChainAsset,
        interactor: StakingRedeemConfirmationInteractorInputProtocol,
        wireframe: StakingRedeemConfirmationWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        wallet: MetaAccountModel,
        container: StakingRedeemConfirmationDependencyContainer
    ) -> StakingRedeemConfirmationPresenter {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        return StakingRedeemConfirmationPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: container.viewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            viewModelState: container.viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        container: StakingRedeemConfirmationDependencyContainer
    ) -> StakingRedeemConfirmationInteractor? {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        return StakingRedeemConfirmationInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            strategy: container.strategy
        )
    }

    // swiftlint:disable function_body_length
    private static func createContainer(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: StakingRedeemConfirmationFlow,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> StakingRedeemConfirmationDependencyContainer? {
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

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let feeProxy = ExtrinsicFeeProxy()

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )

        let slashesOperationFactory = SlashesOperationFactory(
            storageRequestFactory: storageOperationFactory
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

            selectedMetaAccount: wallet
        )

        let callFactory = SubstrateCallFactoryAssembly.createCallFactory(for: runtimeService.runtimeSpecVersion)

        switch flow {
        case .relaychain:
            let viewModelState = StakingRedeemConfirmationRelaychainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = StakingRedeemConfirmationRelaychainStrategy(
                output: viewModelState,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                feeProxy: feeProxy,
                slashesOperationFactory: slashesOperationFactory,
                runtimeService: runtimeService,
                engine: connection,
                operationManager: operationManager,
                keystore: Keychain(),
                accountRepository: AnyDataProviderRepository(accountRepository)
            )
            let viewModelFactory = StakingRedeemConfirmationRelaychainViewModelFactory(
                asset: chainAsset.asset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
            )

            return StakingRedeemConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(collator, delegation, readyForRevoke):
            let viewModelState = StakingRedeemConfirmationParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                delegation: delegation,
                collator: collator,
                readyForRevoke: readyForRevoke,
                callFactory: callFactory
            )

            let strategy = StakingRedeemConfirmationParachainStrategy(
                output: viewModelState,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                signingWrapper: signingWrapper,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                engine: connection,
                operationManager: operationManager,
                keystore: Keychain(),
                eventCenter: EventCenter.shared
            )

            let viewModelFactory = StakingRedeemConfirmationParachainViewModelFactory(
                asset: chainAsset.asset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
            )

            return StakingRedeemConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .pool:
            let viewModelState = StakingRedeemConfirmationPoolViewModelState(
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let viewModelFactory = StakingRedeemConfirmationPoolViewModelFactory(
                asset: chainAsset.asset,
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator(chain: chainAsset.chain)
            )
            let strategy = StakingRedeemConfirmationPoolStrategy(
                output: viewModelState,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                chainAsset: chainAsset,
                wallet: wallet,
                extrinsicService: extrinsicService,
                signingWrapper: signingWrapper,
                feeProxy: feeProxy,
                runtimeService: runtimeService,
                engine: connection,
                operationManager: operationManager,
                keystore: Keychain(),
                eventCenter: EventCenter.shared,
                slashesOperationFactory: slashesOperationFactory,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory
            )
            return StakingRedeemConfirmationDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
