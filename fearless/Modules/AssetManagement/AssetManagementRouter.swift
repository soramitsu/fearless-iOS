import Foundation
import SSFModels

final class AssetManagementRouter: AssetManagementRouterInput {
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    ) {
        guard
            let module = NetworkManagmentAssembly.configureModule(
                wallet: wallet,
                chains: nil,
                contextTag: nil,
                moduleOutput: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }

    func showAddERC20Token(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        moduleOutput: AddERC20TokenModuleOutput?
    ) {
        guard let module = AddERC20TokenAssembly.configureModule(wallet: wallet, moduleOutput: moduleOutput) else {
            return
        }

        let navigationController = FearlessNavigationController(
            rootViewController: module.view.controller
        )
        view?.controller.present(navigationController, animated: true)
    }
}
