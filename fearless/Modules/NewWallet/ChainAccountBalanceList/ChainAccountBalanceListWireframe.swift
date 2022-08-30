import Foundation
import UIKit

final class ChainAccountBalanceListWireframe: ChainAccountBalanceListWireframeProtocol {
    func showChainAccount(
        from view: ChainAccountBalanceListViewProtocol?,
        chainAsset: ChainAsset
    ) {
        guard let chainAccountView = WalletChainAccountDashboardViewFactory.createView(
            chainAsset: chainAsset
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

    func showManageAssets(
        from view: ChainAccountBalanceListViewProtocol?,
        chainModels: [ChainModel]
    ) {
        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let manageAssetsController = ManageAssetsViewFactory.createView(
                selectedMetaAccount: selectedMetaAccount,
                chainModels: chainModels
            )?.controller
        else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: manageAssetsController)

        view?.controller.present(
            navigationController,
            animated: true,
            completion: nil
        )
    }

    func presentSelectCurrency(
        from view: ControllerBackedProtocol?,
        supportedCurrencys: [Currency],
        selectedCurrency: Currency,
        callback: @escaping ModalPickerSelectionCallback
    ) {
        guard
            let pickerView = ModalPickerFactory.createPickerForSelectCurrency(
                supportedCurrencys: supportedCurrencys,
                selectedCurrency: selectedCurrency,
                callback: callback
            )
        else { return }

        view?.controller.navigationController?.present(pickerView, animated: true)
    }
}
