import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsRewardsViewFactory {
    static func createView(
        accountIsNominator: Bool,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) -> AnalyticsRewardsViewProtocol? {
        guard let interactor = createInteractor(
            selectedAccount: selectedAccount,
            chain: chain,
            asset: asset
        ) else {
            return nil
        }

        let wireframe = AnalyticsRewardsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: asset.displayInfo,
            limit: StakingConstants.maxAmount,
            settings: SettingsManager.shared
        )

        let viewModelFactory = AnalyticsRewardsViewModelFactory(
            assetInfo: asset.displayInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            calendar: Calendar(identifier: .gregorian)
        )

        let presenter = AnalyticsRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            accountIsNominator: accountIsNominator,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount,
            logger: Logger.shared
        )

        let view = AnalyticsRewardsViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        selectedAccount: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) -> AnalyticsRewardsInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager

        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)
        let stakingLocalSubscriptionFactory = StakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        return AnalyticsRewardsInteractor(
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationManager: operationManager,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        )
    }
}
