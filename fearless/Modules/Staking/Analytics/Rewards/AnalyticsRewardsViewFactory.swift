import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsRewardsViewFactory {
    static func createView(
        flow: AnalyticsRewardsFlow,
        accountIsNominator: Bool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> AnalyticsRewardsViewProtocol? {
        guard let container = createContainer(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return nil
        }

        let interactor = createInteractor(
            wallet: wallet,
            chainAsset: chainAsset, strategy: container.strategy
        )

        let wireframe = AnalyticsRewardsWireframe()

        let presenter = AnalyticsRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            localizationManager: LocalizationManager.shared,
            accountIsNominator: accountIsNominator,
            chainAsset: chainAsset,
            wallet: wallet,
            logger: Logger.shared
        )

        let view = AnalyticsRewardsViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        strategy: AnalyticsRewardsStrategy
    ) -> AnalyticsRewardsInteractor {
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        return AnalyticsRewardsInteractor(
            strategy: strategy,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset,
            wallet: wallet
        )
    }

    private static func createContainer(
        flow: AnalyticsRewardsFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> AnalyticsRewardsDependencyContainer? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        switch flow {
        case .relaychain:
            let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
                chainRegistry: chainRegistry,
                storageFacade: substrateStorageFacade,
                operationManager: operationManager,
                logger: Logger.shared
            )

            let viewModelState = AnalyticsRewardsRelaychainViewModelState()

            let strategy = AnalyticsRewardsRelaychainStrategy(
                stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
                operationManager: operationManager,
                logger: Logger.shared,
                chainAsset: chainAsset,
                wallet: wallet,
                output: viewModelState
            )

            let viewModelFactory = AnalyticsRewardsRelaychainViewModelFactory(
                assetInfo: chainAsset.asset.displayInfo,
                balanceViewModelFactory: balanceViewModelFactory,
                calendar: Calendar(identifier: .gregorian)
            )

            return AnalyticsRewardsDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .parachain:
            let viewModelState = AnalyticsRewardsParachainViewModelState(
                chainAsset: chainAsset,
                wallet: wallet
            )

            let strategy = AnalyticsRewardsParachainStrategy(
                operationManager: operationManager,
                logger: Logger.shared,
                chainAsset: chainAsset,
                wallet: wallet,
                output: viewModelState
            )

            let viewModelFactory = AnalyticsRewardsParachainViewModelFactory(
                assetInfo: chainAsset.asset.displayInfo,
                balanceViewModelFactory: balanceViewModelFactory,
                calendar: Calendar(identifier: .gregorian)
            )

            return AnalyticsRewardsDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
