import Foundation

final class WalletOptionRouter: WalletOptionRouterInput {
    func showExportWallet(from view: ControllerBackedProtocol?, wallet: ManagedMetaAccountModel) {
        guard let module = SelectExportAccountAssembly.configureModule(managedMetaAccountModel: wallet) else {
            return
        }
        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showWalletDetails(from view: ControllerBackedProtocol?, for wallet: MetaAccountModel) {
        let module = WalletDetailsViewFactory.createView(flow: .normal(wallet: wallet))
        let navigationController = FearlessNavigationController(
            rootViewController: module.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func dismiss(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
