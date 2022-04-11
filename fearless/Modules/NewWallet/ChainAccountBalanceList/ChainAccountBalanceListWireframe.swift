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

        walletSelection.hidesBottomBarWhenPushed = false

        view?.controller.navigationController?.pushViewController(
            walletSelection,
            animated: true
        )
    }

    func showManageAssets(from view: ChainAccountBalanceListViewProtocol?) {
        guard let selectedMetaAccount = SelectedWalletSettings.shared.value,
              let manageAssetsController = ManageAssetsViewFactory.createView(selectedMetaAccount: selectedMetaAccount)?.controller else {
            return
        }

        let navigationController = UINavigationController(rootViewController: manageAssetsController)

        view?.controller.present(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
