import Foundation

final class ChainAssetListRouter: ChainAssetListRouterInput {
    func showChainAccount(
        from view: ChainAssetListViewInput?,
        chainAsset: ChainAsset
    ) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createView(
            chainAsset: chainAsset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }
}
