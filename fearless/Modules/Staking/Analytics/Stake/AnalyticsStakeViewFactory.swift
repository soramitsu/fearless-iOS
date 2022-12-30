import Foundation
import SoraKeystore
import SoraFoundation

struct AnalyticsStakeViewFactory {
    static func createView(
        with wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> AnalyticsStakeViewProtocol? {
        let operationManager = OperationManagerFacade.sharedManager
        guard
            let accountAddress = wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
        else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
        )

        let stakingLocalSubscriptionFactory = RelaychainStakingLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: substrateStorageFacade,
            operationManager: operationManager,
            logger: Logger.shared
        )

        let interactor = AnalyticsStakeInteractor(
            stakingLocalSubscriptionFactory: stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationManager: operationManager,
            selectedAccountAddress: accountAddress,
            chainAsset: chainAsset
        )
        let wireframe = AnalyticsStakeWireframe()

        let viewModelFactory = AnalyticsStakeViewModelFactory(
            assetInfo: chainAsset.asset.displayInfo,
            balanceViewModelFactory: balanceViewModelFactory,
            calendar: Calendar(identifier: .gregorian)
        )
        let presenter = AnalyticsStakePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            wallet: wallet,
            chainAsset: chainAsset
        )

        let view = AnalyticsStakeViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
