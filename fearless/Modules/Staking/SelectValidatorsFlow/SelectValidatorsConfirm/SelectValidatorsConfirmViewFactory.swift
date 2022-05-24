import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import FearlessUtils

final class SelectValidatorsConfirmViewFactory: SelectValidatorsConfirmViewFactoryProtocol {
    private static func createContainer(
        flow: SelectValidatorsConfirmFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> SelectValidatorsConfirmDependencyContainer? {
        let operationManager = OperationManagerFacade.sharedManager

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chain = chainAsset.chain

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let accountResponse = wallet.fetch(for: chain.accountRequest()) else {
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
            metaId:
            wallet.metaId,
            accountResponse: accountResponse
        )

        let logger = Logger.shared
        let storageFacade = SubstrateDataStorageFacade.shared

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
            operationManager: operationManager,
            logger: logger
        )
        let priceLocalSubcriptionFactory = PriceProviderFactory(storageFacade: storageFacade)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            priceAssetInfo: AssetBalanceDisplayInfo.usd(),
            limit: StakingConstants.maxAmount
        )

        switch flow {
        case let .relaychainInitiated(targets, maxTargets, bonding):
            let viewModelState = SelectValidatorsConfirmRelaychainInitiatedViewModelState(
                targets: targets,
                maxTargets: maxTargets,
                initiatedBonding: bonding,
                chainAsset: chainAsset,
                wallet: wallet
            )
            let strategy = SelectValidatorsConfirmRelaychainInitiatedStrategy(
                balanceAccountId: accountResponse.accountId,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                    walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                    selectedMetaAccount: wallet
                ),
                priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
                extrinsicService: extrinsicService,
                runtimeService: runtimeService,
                durationOperationFactory: StakingDurationOperationFactory(),
                operationManager: OperationManagerFacade.sharedManager,
                signer: signer,
                chainAsset: chainAsset,
                output: viewModelState
            )
            let viewModelFactory = SelectValidatorsConfirmRelaychainInitiatedViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)

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
                operationManager: OperationManagerFacade.sharedManager
            )
            let strategy = SelectValidatorsConfirmRelaychainExistingStrategy(
                balanceAccountId: accountResponse.accountId,
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                    walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
                    selectedMetaAccount: wallet
                ),
                priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
                extrinsicService: extrinsicService,
                runtimeService: runtimeService,
                durationOperationFactory: StakingDurationOperationFactory(),
                operationManager: OperationManagerFacade.sharedManager,
                signer: signer,
                chainAsset: chainAsset,
                output: viewModelState
            )
            let viewModelFactory = SelectValidatorsConfirmRelaychainExistingViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)

            return SelectValidatorsConfirmDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .parachain:
            return nil
        }
    }

    static func createInitiatedBondingView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = SelectValidatorsConfirmWireframe()

        return createView(
            chainAsset: chainAsset,
            flow: flow,
            wallet: wallet,
            wireframe: wireframe
        )
    }

    static func createChangeTargetsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = SelectValidatorsConfirmWireframe()
        return createExistingBondingView(
            wallet: wallet,
            chainAsset: chainAsset,
            flow: flow,
            wireframe: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        return createExistingBondingView(
            wallet: wallet,
            chainAsset: chainAsset,
            flow: flow,
            wireframe: wireframe
        )
    }

    private static func createExistingBondingView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow,
        wireframe: SelectValidatorsConfirmWireframeProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        createView(
            chainAsset: chainAsset,
            flow: flow,
            wallet: wallet,
            wireframe: wireframe
        )
    }

    private static func createView(
        chainAsset: ChainAsset,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        wireframe: SelectValidatorsConfirmWireframeProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        guard let container = createContainer(flow: flow, chainAsset: chainAsset, wallet: wallet),
              let interactor = createInteractor(wallet: wallet, asset: chainAsset.asset, strategy: container.strategy) else {
            return nil
        }

        let errorBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            priceAssetInfo: AssetBalanceDisplayInfo.usd(),
            formatterFactory: AssetBalanceFormatterFactory(),
            limit: StakingConstants.maxAmount
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: errorBalanceViewModelFactory
        )

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
        wallet _: MetaAccountModel,
        asset: AssetModel,
        strategy: SelectValidatorsConfirmStrategy
    ) -> SelectValidatorsConfirmInteractorBase? {
        let priceLocalSubcriptionFactory = PriceProviderFactory(storageFacade: SubstrateDataStorageFacade.shared)

        return SelectValidatorsConfirmInteractorBase(
            priceLocalSubscriptionFactory: priceLocalSubcriptionFactory,
            asset: asset,
            strategy: strategy
        )
    }
}
