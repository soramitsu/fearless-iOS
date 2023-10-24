import Foundation
import SSFCloudStorage

extension AddAccount {
    final class OnboardingMainWireframe: OnboardingMainWireframeProtocol {
        func showPreinstalledFlow(from view: ControllerBackedProtocol?) {
            let module = GetPreinstalledWalletAssembly.configureModuleForNewUser()

            guard let controller = module?.view.controller else {
                return
            }

            view?.controller.navigationController?.pushViewController(controller, animated: true)
        }

        func showQR(moduleOutput: ScanQRModuleOutput, from view: ControllerBackedProtocol?) {
            let module = ScanQRAssembly.configureModule(moduleOutput: moduleOutput)

            guard let controller = module?.view.controller else {
                return
            }

            view?.controller.present(controller, animated: true)
        }

        func showBackupSelectWallet(
            accounts: [SSFCloudStorage.OpenBackupAccount],
            from view: ControllerBackedProtocol?
        ) {
            guard let controller = BackupSelectWalletAssembly.configureModule(accounts: accounts)?.view.controller else {
                return
            }

            view?.controller.navigationController?.pushViewController(controller, animated: true)
        }

        func showSignup(from view: OnboardingMainViewProtocol?) {
            guard let usernameSetup = UsernameSetupViewFactory.createViewForAdding() else {
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
                .createViewForAdding(defaultSource: defaultSource)?.controller
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
                navigationController.topViewController == view?.controller,
                navigationController.presentedViewController == nil {
                showAccountRestore(defaultSource: .mnemonic, from: view)
            }
        }

        func showCreateFlow(from view: ControllerBackedProtocol?) {
            guard let controller = WalletNameAssembly.configureModule(with: nil)?.view.controller else {
                return
            }
            view?.controller.navigationController?.pushViewController(controller, animated: true)
        }
    }
}
