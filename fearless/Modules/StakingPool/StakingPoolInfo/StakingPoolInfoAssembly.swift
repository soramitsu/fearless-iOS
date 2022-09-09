import UIKit
import SoraFoundation

final class StakingPoolInfoAssembly {
    static func configureModule(
        stakingPool: StakingPool,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> StakingPoolInfoModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let logger = Logger.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(storageFacade: substrateStorageFacade)

        let interactor = StakingPoolInfoInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset
        )
        let router = StakingPoolInfoRouter()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )
        let viewModelFactory = StakingPoolInfoViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = StakingPoolInfoPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            stakingPool: stakingPool,
            chainAsset: chainAsset,
            logger: logger,
            localizationManager: localizationManager
        )

        let view = StakingPoolInfoViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
