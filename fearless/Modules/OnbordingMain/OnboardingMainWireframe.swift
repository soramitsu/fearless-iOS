import Foundation
import SSFCloudStorage

final class OnboardingMainWireframe: OnboardingMainWireframeProtocol {
    func showSignup(from view: OnboardingMainViewProtocol?) {
        guard let usernameSetup = UsernameSetupViewFactory.createViewForOnboarding() else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(usernameSetup.controller, animated: true)
        }
    }

    func showAccountRestore(
        defaultSource: AccountImportSource,
        from view: OnboardingMainViewProtocol?
    ) {
        guard let restorationController = AccountImportViewFactory
            .createViewForOnboarding(defaultSource: defaultSource)?.controller
        else {
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
            showAccountRestore(defaultSource: .keystore, from: view)
        }
    }

    func showBackupSelectWallet(
        accounts: [OpenBackupAccount],
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = BackupSelectWalletAssembly.configureModule(accounts: accounts)?.view.controller else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: controller)
        view?.controller.present(navigationController, animated: true)
    }

    func showCreateFlow(from view: ControllerBackedProtocol?) {
        guard let controller = WalletNameAssembly.configureModule(with: nil)?.view.controller else {
            return
        }
        let navigation = FearlessNavigationController(rootViewController: controller)
        view?.controller.navigationController?.present(navigation, animated: true)
    }

    func showPreinstalledFlow(from view: ControllerBackedProtocol?) {
        let module = GetPreinstalledWalletAssembly.configureModule()

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
