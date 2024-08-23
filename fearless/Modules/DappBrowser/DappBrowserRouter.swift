import Foundation
import SSFModels

final class DappBrowserRouter: DappBrowserRouterInput {
    func showWalletManagment(
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        guard
            let module = WalletsManagmentAssembly.configureModule(
                shouldSaveSelected: true,
                moduleOutput: moduleOutput
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
    
    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chains: [ChainModel],
        delegate: NetworkManagmentModuleOutput?,
        initialFilter: NetworkManagmentFilter
    ) {
        guard
            let module = NetworkManagmentAssembly.configureModule(
                initialFilter: initialFilter,
                wallet: wallet,
                chains: chains,
                contextTag: nil,
                moduleOutput: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
    
    func showDapp(
        from view: ControllerBackedProtocol?,
        dapp: TonDapp,
        wallet: MetaAccountModel
    ) {
        guard let module = TonWebBridgeAssembly.configureModule(for: dapp, wallet: wallet) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
    
    func showList(
        from view: ControllerBackedProtocol?,
        dapps: [TonDapp],
        title: String,
        wallet: MetaAccountModel
    ) {
        guard let module = DappBrowserListAssembly.configureModule(title: title, dapps: dapps, wallet: wallet) else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
