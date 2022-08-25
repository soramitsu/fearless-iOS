import Foundation

final class ChainAssetListRouter: ChainAssetListRouterInput {
    func showChainAccount(
        from view: ChainAssetListViewInput?,
        chainAsset: ChainAsset,
        availableChainAssets: [ChainAsset]
    ) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createView(
            chainAsset: chainAsset,
            availableChainAssets: availableChainAssets
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }
}
