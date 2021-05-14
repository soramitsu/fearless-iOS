import Foundation

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel) {
        guard let accountCreation = AccountCreateViewFactory.createViewForOnboarding(model: model) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            accountCreation.controller,
            animated: true
        )
    }
}
