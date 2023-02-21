import Foundation

protocol AccountManagementPresentable {
    func showCreateNewWallet(from view: ControllerBackedProtocol?)
    func showImportWallet(from view: ControllerBackedProtocol?)
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

    func showImportWallet(from view: ControllerBackedProtocol?) {
        guard let restorationController = AccountImportViewFactory
            .createViewForAdding()?.controller
        else {
            return
        }

        restorationController.hidesBottomBarWhenPushed = true

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }
}
