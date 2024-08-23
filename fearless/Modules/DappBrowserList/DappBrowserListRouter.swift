import Foundation
import SSFModels

final class DappBrowserListRouter: DappBrowserListRouterInput {
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
}
