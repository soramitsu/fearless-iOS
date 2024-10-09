import UIKit
import SoraFoundation
import SSFModels
import SSFUtils

final class BalanceLocksDetailAssembly {
    static func configureModule(chainAsset: ChainAsset, wallet: MetaAccountModel) -> BalanceLocksDetailModuleCreationResult? {
        guard let balanceLocksFetching = BalanceLocksFetchingFactory.buildBalanceLocksFetcher(for: chainAsset) else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let interactor = BalanceLocksDetailInteractor(
            wallet: wallet,
            chainAsset: chainAsset,
            balanceLocksFetching: balanceLocksFetching
        )
        let router = BalanceLocksDetailRouter()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )
        let viewModelFactory = BalanceLockDetailViewModelFactoryDefault(
            balanceViewModelFactory: balanceViewModelFactory,
            chainAsset: chainAsset
        )

        let presenter = BalanceLocksDetailPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            logger: Logger.shared,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            selectedCurrency: wallet.selectedCurrency
        )

        let view = BalanceLocksDetailViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
