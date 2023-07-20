import Foundation

protocol AccountManagementPresentable {
    func showCreateNewWallet(from view: ControllerBackedProtocol?)
    func showImportWallet(
        defaultSource: AccountImportSource,
        from view: ControllerBackedProtocol?
    )
    func showBackupSelectWallet(from view: ControllerBackedProtocol?)
}

extension AccountManagementPresentable {
    func showCreateNewWallet(from view: ControllerBackedProtocol?) {
        guard let usernameSetup = UsernameSetupViewFactory.createViewForAdding() else {
            return
        }

        usernameSetup.controller.hidesBottomBarWhenPushed = true

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(usernameSetup.controller, animated: true)
        }
    }

    func showImportWallet(
        defaultSource: AccountImportSource,
        from view: ControllerBackedProtocol?
    ) {
        guard let restorationController = AccountImportViewFactory
            .createViewForOnboarding(defaultSource: defaultSource)?.controller
        else {
            return
        }
        restorationController.hidesBottomBarWhenPushed = true
        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }

    func showBackupSelectWallet(from view: ControllerBackedProtocol?) {
        guard let controller = BackupSelectWalletAssembly.configureModule(accounts: nil)?.view.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }
}
