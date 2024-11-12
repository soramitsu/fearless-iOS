import Foundation

final class BackupRiskWarningsRouter: BackupRiskWarningsRouterInput {
    func showCreateAccount(
        usernameModel: UsernameSetupModel,
        from view: ControllerBackedProtocol?
    ) { // TODO: - Select ecosystem
        guard let controller = AccountCreateViewFactory.createViewForOnboarding(ecosystem: .regular, model: usernameModel, flow: .backup)?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
