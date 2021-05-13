import Foundation

extension SwitchAccount {
    final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
        func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel) {
            guard let accountCreation = AccountCreateViewFactory.createViewForSwitch(model: model) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                accountCreation.controller,
                animated: true
            )
        }
    }
}
