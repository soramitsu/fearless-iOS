import Foundation

final class WalletOptionRouter: WalletOptionRouterInput {
    func showExportWallet(from view: ControllerBackedProtocol?, wallet: ManagedMetaAccountModel) {
        guard let module = BackupWalletAssembly.configureModule(wallet: wallet.info) else {
            return
        }
        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showWalletDetails(from view: ControllerBackedProtocol?, for wallet: MetaAccountModel) {
        let module = WalletDetailsViewFactory.createView(flow: .normal(wallet: wallet))
        let navigationController = FearlessNavigationController(
            rootViewController: module.controller
        )

        view?.controller.present(navigationController, animated: true)
    }

    func showChangeWalletName(
        from view: ControllerBackedProtocol?,
        for wallet: MetaAccountModel
    ) {
        guard let controller = WalletNameAssembly.configureModule(with: wallet)?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
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
}
