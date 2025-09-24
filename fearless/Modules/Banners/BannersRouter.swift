import Foundation
import SSFModels

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

    func presentLiquidityPools(
        on view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainId: ChainModel.Id
    ) {
        guard
            let tabBarController = view?.controller,
            let viewController = LiquidityPoolsOverviewAssembly.configureModule(wallet: wallet, chainId: chainId)?.view.controller
        else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: viewController)

        let presentingController = tabBarController.topModalViewController
        presentingController.present(navigationController, animated: true, completion: nil)
    }
}
