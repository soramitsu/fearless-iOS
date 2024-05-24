import Foundation

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
}
