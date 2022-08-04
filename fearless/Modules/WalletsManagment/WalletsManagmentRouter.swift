import Foundation

final class WalletsManagmentRouter: WalletsManagmentRouterInput {
    func showOptions(
        from view: WalletsManagmentViewInput?,
        metaAccount: ManagedMetaAccountModel
    ) {
        guard
            let walletOptionsController = WalletOptionAssembly.configureModule(
                with: metaAccount
            )?.view.controller
        else {
            return
        }

        view?.controller.present(walletOptionsController, animated: true)
    }

    func dissmis(
        view: WalletsManagmentViewInput?,
        dissmisCompletion: @escaping () -> Void
    ) {
        view?.controller.dismiss(animated: true, completion: dissmisCompletion)
    }
}
