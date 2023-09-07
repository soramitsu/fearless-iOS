import Foundation
import WalletConnectSign

final class WalletConnectActiveSessionsRouter: WalletConnectActiveSessionsRouterInput {
    func showSession(
        _ session: Session,
        view: ControllerBackedProtocol?
    ) {
        let module = WalletConnectProposalAssembly.configureModule(status: .active(session))
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }

    func showScaner(
        output: ScanQRModuleOutput,
        view: ControllerBackedProtocol?
    ) {
        let module = ScanQRAssembly.configureModule(moduleOutput: output, matchers: [ScanQRAssembly.wcSchemeMatcher])
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}
