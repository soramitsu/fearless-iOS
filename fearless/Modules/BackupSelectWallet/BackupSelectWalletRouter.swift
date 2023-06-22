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
}
