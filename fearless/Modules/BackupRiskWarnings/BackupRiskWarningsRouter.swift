import Foundation

final class BackupRiskWarningsRouter: BackupRiskWarningsRouterInput {
    func showCreateAccount(
        usernameModel: UsernameSetupModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = AccountCreateViewFactory
            .createViewForOnboarding(model: usernameModel, flow: .backup)?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
