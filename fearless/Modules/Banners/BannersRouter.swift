import Foundation

final class BannersRouter: BannersRouterInput {
    func showWalletBackupScreen(
        for wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = BackupWalletAssembly.configureModule(wallet: wallet) else {
            return
        }

        let navigation = FearlessNavigationController(rootViewController: module.view.controller)
        view?.controller.present(navigation, animated: true)
    }
}
