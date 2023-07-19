import Foundation
import SSFCloudStorage

final class BackupSelectWalletRouter: BackupSelectWalletRouterInput {
    func presentBackupPasswordScreen(
        for backupAccounts: [BackupAccount],
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = BackupPasswordAssembly.configureModule(backupAccounts: backupAccounts)?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }

    func showWalletNameScreen(from view: ControllerBackedProtocol?) {
        guard let module = BackupWalletNameAssembly.configureModule(with: nil) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
