import Foundation

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    func proceed(
        from view: UsernameSetupViewProtocol?,
        flow: AccountCreateFlow,
        model: UsernameSetupModel
    ) {
        guard let accountCreation = AccountCreateViewFactory.createViewForOnboarding(
            model: model,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            accountCreation.controller,
            animated: true
        )
    }
}
