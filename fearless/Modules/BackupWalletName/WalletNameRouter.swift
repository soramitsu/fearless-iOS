import Foundation
import UIKit

final class WalletNameRouter: WalletNameRouterInput {
    func showWarningsScreen(
        walletName: String,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = BackupRiskWarningsAssembly.configureModule(walletName: walletName)?.view.controller else {
            return
        }
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func complete(view _: ControllerBackedProtocol?) {
        UIApplication.shared.keyWindow?.rootViewController?.dismiss(animated: true, completion: nil)
    }
}
