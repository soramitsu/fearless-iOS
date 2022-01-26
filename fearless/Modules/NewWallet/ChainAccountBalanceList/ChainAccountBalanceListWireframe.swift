import Foundation
import UIKit

final class ChainAccountBalanceListWireframe: ChainAccountBalanceListWireframeProtocol {
    func showChainAccount(
        from view: ChainAccountBalanceListViewProtocol?,
        chain: ChainModel,
        asset: AssetModel
    ) {
        guard let chainAccountView = WalletChainAccountDashboardViewFactory.createView(
            chain: chain,
            asset: asset
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(chainAccountView.controller, animated: true)
    }

    func showWalletSelection(from view: ChainAccountBalanceListViewProtocol?) {
        guard let walletSelection = AccountManagementViewFactory.createViewForSettings()?.controller else {
            return
        }

//        walletSelection.controller.hidesBottomBarWhenPushed = false

        let navigationController = UINavigationController(rootViewController: walletSelection)
        view?.controller.present(navigationController, animated: true, completion: nil)
//        view?.controller.navigationController?.pushViewController(
//            walletSelection.controller,
//            animated: true
//        )
    }
}
