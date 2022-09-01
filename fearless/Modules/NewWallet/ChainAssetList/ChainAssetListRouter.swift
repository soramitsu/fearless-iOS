import Foundation

final class ChainAssetListRouter: ChainAssetListRouterInput {
    func showChainAccount(from view: ChainAssetListViewInput?, chainAsset: ChainAsset) {
        guard let chainAssetView = WalletChainAccountDashboardViewFactory.createView(
            chain: chainAsset.chain,
            asset: chainAsset.asset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            chainAssetView.controller,
            animated: true
        )
    }
}
