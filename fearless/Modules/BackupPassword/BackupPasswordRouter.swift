import Foundation

final class BackupPasswordRouter: BackupPasswordRouterInput {
    func showWalletImportedScreen(backupAccounts: [BackupAccount], from view: ControllerBackedProtocol?) {
        guard let controller = BackupWalletImportedAssembly.configureModule(backupAccounts: backupAccounts)?.view.controller else {
            return
        }
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
