import Foundation

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    func proceed(
        from view: UsernameSetupViewProtocol?,
        flow: AccountCreateFlow,
        model: UsernameSetupModel,
        ecosystem: AccountCreateEcosystem
    ) {
        guard let accountCreation = AccountCreateViewFactory.createViewForOnboarding(
            ecosystem: ecosystem, 
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
