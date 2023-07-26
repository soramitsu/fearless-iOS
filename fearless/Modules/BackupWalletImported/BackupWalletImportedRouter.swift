import Foundation
import SSFCloudStorage

final class BackupWalletImportedRouter: BackupWalletImportedRouterInput {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

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

    func showSetupPin() {
        guard let controller = PinViewFactory.createPinSetupView()?.controller else {
            return
        }
        rootAnimator.animateTransition(to: controller)
    }

    func backButtonDidTapped(from view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(animated: true)
    }
}
