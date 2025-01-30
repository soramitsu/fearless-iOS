import Foundation
import SSFModels

final class WalletOptionRouter: WalletOptionRouterInput {
    func showExportWallet(from view: ControllerBackedProtocol?, wallet: MetaAccountModel) {
        guard let module = BackupWalletAssembly.configureModule(wallet: wallet) else {
            return
        }
        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showWalletDetails(from view: ControllerBackedProtocol?, for wallet: MetaAccountModel) {
        guard let module = ConnectedAccountsAssembly.configureModule(wallet: wallet) else {
            return
        }
        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showChangeWalletName(
        from view: ControllerBackedProtocol?,
        for wallet: MetaAccountModel
    ) {
        guard let controller = WalletNameAssembly.configureModule(with: wallet)?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}
