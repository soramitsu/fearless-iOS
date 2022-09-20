import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

final class SelectValidatorsConfirmViewFactory: SelectValidatorsConfirmViewFactoryProtocol {
    // swiftlint:disable function_body_length
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

        let extrinsicService = ExtrinsicService(
            accountId: accountResponse.accountId,
            chainFormat: chain.chainFormat,
            cryptoType: accountResponse.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: Keychain(),
            metaId: wallet.metaId,
            accountResponse: accountResponse
        )

        let logger = Logger.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )

        let priceLocalSubcriptionFactory = PriceProviderFactory(storageFacade: storageFacade)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
        )

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)
        let iconGenerator = UniversalIconGenerator(chain: chain)

        switch flow {
        case let .relaychainInitiated(targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmRelaychainInitiatedViewModelState(
                targets: targets,
                maxTargets: maxTargets,
                initiatedBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet, dataValidatingFactory: dataValidatingFactory
            )
            let strategy = SelectValidatorsConfirmRelaychainInitiatedStrategy(
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
                iconGenerator: iconGenerator
            )

            return SelectValidatorsConfirmDependencyContainer(viewModelState: viewModelState, strategy: strategy, viewModelFactory: viewModelFactory)
        case let .relaychainExisting(targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmRelaychainExistingViewModelState(
                targets: targets,
                maxTargets: maxTargets,
                existingBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet,
                operationManager: OperationManagerFacade.sharedManager, dataValidatingFactory: dataValidatingFactory
            )
            let strategy = SelectValidatorsConfirmRelaychainExistingStrategy(
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
            let viewModelFactory = SelectValidatorsConfirmRelaychainExistingViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator
            )

            return SelectValidatorsConfirmDependencyContainer(viewModelState: viewModelState, strategy: strategy, viewModelFactory: viewModelFactory)
        case let .parachain(target, maxTargets, bonding):
            let subqueryOperationFactory = SubqueryRewardOperationFactory(
                url: chainAsset.chain.externalApi?.staking?.url
            )

            let collatorOperationFactory = ParachainCollatorOperationFactory(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                storageRequestFactory: storageOperationFactory,
                runtimeService: runtimeService,
                engine: connection,
                identityOperationFactory: identityOperationFactory,
                subqueryOperationFactory: subqueryOperationFactory
            )

            let viewModelState = SelectValidatorsConfirmParachainViewModelState(
                target: target,
                maxTargets: maxTargets,
                initiatedBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet, dataValidatingFactory: dataValidatingFactory
            )
            let strategy = SelectValidatorsConfirmParachainStrategy(
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
                iconGenerator: UniversalIconGenerator(chain: chain)
            )
            return SelectValidatorsConfirmDependencyContainer(viewModelState: viewModelState, strategy: strategy, viewModelFactory: viewModelFactory)
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
        }

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            formatterFactory: AssetBalanceFormatterFactory(),
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

        guard let container = createContainer(flow: flow, chainAsset: chainAsset, wallet: wallet, dataValidatingFactory: dataValidatingFactory),
              let interactor = createInteractor(wallet: wallet, chainAsset: chainAsset, strategy: container.strategy) else {
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
        let priceLocalSubcriptionFactory = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

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
