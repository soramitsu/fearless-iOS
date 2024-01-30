import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFUtils
import SSFModels

// swiftlint:disable type_body_length function_body_length
final class SelectValidatorsConfirmViewFactory: SelectValidatorsConfirmViewFactoryProtocol {
    private static func createSigner(
        wallet: MetaAccountModel,
        flow: SelectValidatorsConfirmFlow,
        accountResponse: ChainAccountResponse
    ) -> SigningWrapperProtocol {
        switch flow {
        case let .relaychainExisting(_, _, bonding):
            return SigningWrapper(
                keystore: Keychain(),
                metaId: bonding.controllerAccount.walletId,
                accountResponse: bonding.controllerAccount
            )
        default:
            return SigningWrapper(
                keystore: Keychain(),
                metaId: wallet.metaId,
                accountResponse: accountResponse
            )
        }
    }

    private static func createExtrinsicService(
        for account: ChainAccountResponse,
        runtimeService: RuntimeProviderProtocol,
        connection: ChainConnection,
        operationManager: OperationManagerProtocol,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> ExtrinsicServiceProtocol {
        switch flow {
        case let .relaychainExisting(_, _, bonding):
            return ExtrinsicService(
                accountId: bonding.controllerAccount.accountId,
                chainFormat: chainAsset.chain.chainFormat,
                cryptoType: bonding.controllerAccount.cryptoType,
                runtimeRegistry: runtimeService,
                engine: connection,
                operationManager: operationManager
            )
        default:
            return ExtrinsicService(
                accountId: account.accountId,
                chainFormat: chainAsset.chain.chainFormat,
                cryptoType: account.cryptoType,
                runtimeRegistry: runtimeService,
                engine: connection,
                operationManager: operationManager
            )
        }
    }

    private static func createContainer(
        flow: SelectValidatorsConfirmFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        dataValidatingFactory: StakingDataValidatingFactory
    ) -> SelectValidatorsConfirmDependencyContainer? {
        let operationManager = OperationManagerFacade.sharedManager

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chain = chainAsset.chain

        let storageFacade = SubstrateDataStorageFacade.shared
        let serviceFactory = StakingServiceFactory(
            chainRegisty: chainRegistry,
            storageFacade: storageFacade,
            eventCenter: EventCenter.shared,
            operationManager: OperationManagerFacade.sharedManager
        )
        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let accountResponse = wallet.fetch(for: chain.accountRequest()),
            let eraValidatorService = try? serviceFactory.createEraValidatorService(for: chainAsset.chain) else {
            return nil
        }

        let logger = Logger.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let priceLocalSubcriptionFactory = PriceProviderFactory.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)
        let iconGenerator = UniversalIconGenerator()

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: storageOperationFactory,
            chainRegistry: chainRegistry
        )

        let extrinsicService = createExtrinsicService(
            for: accountResponse,
            runtimeService: runtimeService,
            connection: connection,
            operationManager: operationManager,
            chainAsset: chainAsset,
            flow: flow
        )

        let signer = createSigner(
            wallet: wallet,
            flow: flow,
            accountResponse: accountResponse
        )

        let callFactory = SubstrateCallFactoryDefault(runtimeService: runtimeService)

        switch flow {
        case let .relaychainInitiated(targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmRelaychainInitiatedViewModelState(
                targets: targets,
                maxTargets: maxTargets,
                initiatedBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = SelectValidatorsConfirmRelaychainInitiatedStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                balanceAccountId: accountResponse.accountId,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
                extrinsicService: extrinsicService,
                runtimeService: runtimeService,
                durationOperationFactory: StakingDurationOperationFactory(),
                operationManager: OperationManagerFacade.sharedManager,
                signer: signer,
                chainAsset: chainAsset,
                output: viewModelState
            )
            let viewModelFactory = SelectValidatorsConfirmRelaychainInitiatedViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator,
                chainAsset: chainAsset
            )

            return SelectValidatorsConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .relaychainExisting(targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmRelaychainExistingViewModelState(
                targets: targets,
                maxTargets: maxTargets,
                existingBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet,
                operationManager: OperationManagerFacade.sharedManager,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = SelectValidatorsConfirmRelaychainExistingStrategy(
                balanceAccountId: bonding.controllerAccount.accountId,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
                extrinsicService: extrinsicService,
                runtimeService: runtimeService,
                durationOperationFactory: StakingDurationOperationFactory(),
                operationManager: OperationManagerFacade.sharedManager,
                signer: signer,
                chainAsset: chainAsset,
                output: viewModelState,
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter
            )
            let viewModelFactory = SelectValidatorsConfirmRelaychainExistingViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator,
                chainAsset: chainAsset
            )

            return SelectValidatorsConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(target, maxTargets, bonding):
            let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

            let collatorOperationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageOperationFactory,
                identityOperationFactory: identityOperationFactory,
                subqueryOperationFactory: rewardOperationFactory,
                chainRegistry: chainRegistry
            )

            let viewModelState = SelectValidatorsConfirmParachainViewModelState(
                target: target,
                maxTargets: maxTargets,
                initiatedBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = SelectValidatorsConfirmParachainStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                collatorAccountId: target.owner,
                balanceAccountId: accountResponse.accountId,
                runtimeService: runtimeService,
                extrinsicService: extrinsicService,
                signer: signer,
                operationManager: operationManager,
                chainAsset: chainAsset,
                output: viewModelState,
                collatorOperationFactory: collatorOperationFactory,
                eraInfoOperationFactory: ParachainStakingInfoOperationFactory(),
                eraValidatorService: eraValidatorService
            )
            let viewModelFactory = SelectValidatorsConfirmParachainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: UniversalIconGenerator(),
                chainAsset: chainAsset
            )
            return SelectValidatorsConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .poolInitiated(poolId, targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmPoolInitiatedViewModelState(
                poolId: poolId,
                targets: targets,
                maxTargets: maxTargets,
                initiatedBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = SelectValidatorsConfirmPoolInitiatedStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                balanceAccountId: accountResponse.accountId,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
                extrinsicService: extrinsicService,
                runtimeService: runtimeService,
                durationOperationFactory: StakingDurationOperationFactory(),
                operationManager: OperationManagerFacade.sharedManager,
                signer: signer,
                chainAsset: chainAsset,
                output: viewModelState,
                stakingPoolOperationFactory: stakingPoolOperationFactory,
                poolId: poolId
            )
            let viewModelFactory = SelectValidatorsConfirmPoolInitiatedViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator,
                chainAsset: chainAsset
            )

            return SelectValidatorsConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .poolExisting(poolId, targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmPoolExistingViewModelState(
                poolId: poolId,
                targets: targets,
                maxTargets: maxTargets,
                existingBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet,
                operationManager: OperationManagerFacade.sharedManager,
                dataValidatingFactory: dataValidatingFactory,
                callFactory: callFactory
            )
            let strategy = SelectValidatorsConfirmPoolExistingStrategy(
                accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
                balanceAccountId: accountResponse.accountId,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
                extrinsicService: extrinsicService,
                runtimeService: runtimeService,
                durationOperationFactory: StakingDurationOperationFactory(),
                operationManager: OperationManagerFacade.sharedManager,
                signer: signer,
                chainAsset: chainAsset,
                output: viewModelState,
                stakingPoolOperationFactory: stakingPoolOperationFactory,
                poolId: poolId
            )
            let viewModelFactory = SelectValidatorsConfirmPoolExistingViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator,
                chainAsset: chainAsset
            )

            return SelectValidatorsConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }

    static func createView(
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel
    ) -> SelectValidatorsConfirmViewProtocol? {
        var wireframe: SelectValidatorsConfirmWireframeProtocol
        switch flow {
        case .relaychainInitiated:
            wireframe = SelectValidatorsConfirmWireframe()
        case .relaychainExisting:
            wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        case .parachain:
            wireframe = SelectValidatorsConfirmWireframe()
        case .poolInitiated:
            wireframe = SelectValidatorsConfirmWireframe()
        case .poolExisting:
            wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        }

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            formatterFactory: AssetBalanceFormatterFactory(),

            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        guard
            let container = createContainer(
                flow: flow,
                chainAsset: chainAsset,
                wallet: wallet,
                dataValidatingFactory: dataValidatingFactory
            ),
            let interactor = createInteractor(
                wallet: wallet,
                chainAsset: chainAsset,
                strategy: container.strategy
            )
        else {
            return nil
        }

        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            logger: Logger.shared
        )

        let view = SelectValidatorsConfirmViewController(
            presenter: presenter,
            quantityFormatter: .quantity,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        strategy: SelectValidatorsConfirmStrategy
    ) -> SelectValidatorsConfirmInteractorBase? {
        let priceLocalSubcriptionFactory = PriceProviderFactory.shared

        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return nil
        }

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        return SelectValidatorsConfirmInteractorBase(
            balanceAccountId: accountId,
            priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
            chainAsset: chainAsset,
            strategy: strategy,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter
        )
    }
}
