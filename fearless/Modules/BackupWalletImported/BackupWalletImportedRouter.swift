import Foundation
import SSFCloudStorage

final class BackupWalletImportedRouter: BackupWalletImportedRouterInput {
    func showBackupSelectWallet(
        for accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = BackupSelectWalletAssembly.configureModule(accounts: accounts)?.view.controller else {
            return
        }

        let presenter = view?.controller.navigationController?.presentingViewController
        view?.controller.navigationController?.dismiss(animated: true) {
            if let presenter = presenter as? ControllerBackedProtocol {
                let navController = FearlessNavigationController(rootViewController: controller)
                presenter.controller.present(navController, animated: true)
            }
        }
    }

    func showSetupPin(from view: ControllerBackedProtocol?) {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }
        let presenter = view?.controller.navigationController?.presentingViewController
        view?.controller.navigationController?.dismiss(animated: true) {
            if let presenter = presenter as? FearlessNavigationController {
                presenter.pushViewController(controller, animated: true)
            }
        }
    }
}
