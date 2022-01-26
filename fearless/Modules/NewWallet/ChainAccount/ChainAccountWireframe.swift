import Foundation
import UIKit

final class ChainAccountWireframe: ChainAccountWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

    func presentSendFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel
    ) {
        let searchView = SearchPeopleViewFactory.createView(
            chain: chain,
            asset: asset,
            selectedMetaAccount: selectedMetaAccount
        )

        guard let controller = searchView?.controller else {
            return
        }

        let navigationController = UINavigationController(rootViewController: controller)

        view?.controller.present(navigationController, animated: true)
    }

    func presentReceiveFlow(
        from view: ControllerBackedProtocol?,
        asset: AssetModel,
        chain: ChainModel,
        selectedMetaAccount: MetaAccountModel
    ) {
        let receiveView = ReceiveAssetViewFactory.createView(
            account: selectedMetaAccount,
            chain: chain,
            asset: asset
        )

        guard let controller = receiveView?.controller else {
            return
        }

        let navigationController = UINavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }

    func presentBuyFlow(
        from view: ControllerBackedProtocol?,
        items: [PurchaseAction],
        delegate: ModalPickerViewControllerDelegate
    ) {
        let buyView = ModalPickerFactory.createPickerForList(
            items,
            delegate: delegate,
            context: nil
        )

        guard let buyView = buyView else {
            return
        }

        view?.controller.navigationController?.present(buyView, animated: true)
    }

    func presentPurchaseWebView(
        from view: ControllerBackedProtocol?,
        action: PurchaseAction
    ) {
        let webView = PurchaseViewFactory.createView(
            for: action
        )
        view?.controller.dismiss(animated: true, completion: {
            if let webViewController = webView?.controller {
                view?.controller.present(webViewController, animated: true, completion: nil)
            }
        })
    }

    func presentLockedInfo(
        from _: ControllerBackedProtocol?,
        balanceContext: BalanceContext,
        info: AssetBalanceDisplayInfo
    ) {
        ModalInfoFactory.createFromBalanceContext(
            balanceContext,
            amountFormatter: AssetBalanceFormatterFactory().createDisplayFormatter(for: info),
            priceFormatter: AssetBalanceFormatterFactory().createTokenFormatter(for: info),
            precision: info.assetPrecision
        )
    }
}
