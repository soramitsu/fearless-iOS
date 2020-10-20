import Foundation

final class ConnectionMainWireframe: OnboardingMainWireframeProtocol {
    let connectionItem: ConnectionItem

    init(connectionItem: ConnectionItem) {
        self.connectionItem = connectionItem
    }

    func showSignup(from view: OnboardingMainViewProtocol?) {
        guard let usernameSetup = UsernameSetupViewFactory
            .createViewForConnection(item: connectionItem) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(usernameSetup.controller, animated: true)
        }
    }

    func showAccountRestore(from view: OnboardingMainViewProtocol?) {
        guard let restorationController = AccountImportViewFactory
            .createViewForConnection(item: connectionItem)?.controller else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(restorationController, animated: true)
        }
    }

    func showKeystoreImport(from view: OnboardingMainViewProtocol?) {
        if
            let navigationController = view?.controller.navigationController,
            navigationController.viewControllers.count == 1,
            navigationController.presentedViewController == nil {
            showAccountRestore(from: view)
        }
    }
}
