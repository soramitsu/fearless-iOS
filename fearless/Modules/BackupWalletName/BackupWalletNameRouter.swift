import Foundation

final class BackupWalletNameRouter: BackupWalletNameRouterInput {
    func showWarningsScreen(
        walletName: String,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = BackupRiskWarningsAssembly.configureModule(walletName: walletName)?.view.controller else {
            return
        }
        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
