import Foundation
import WalletConnectSign

final class WalletConnectActiveSessionsRouter: WalletConnectActiveSessionsRouterInput {
    func showSession(
        _ action: ActionConnect,
        view: ControllerBackedProtocol?
    ) {
        let module = WalletConnectProposalAssembly.configureModule(status: .active(action))
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }

    func showScaner(
        output: ScanQRModuleOutput,
        view: ControllerBackedProtocol?
    ) {
        let module = ScanQRAssembly.configureModule(
            moduleOutput: output,
            matchers: [
                ScanQRAssembly.wcSchemeMatcher,
                ScanQRAssembly.tonConnectMatcher
            ]
        )
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}
