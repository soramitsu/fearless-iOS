import Foundation

extension AddAccount {
    final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
        func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel) {
            guard let accountCreation = AccountCreateViewFactory.createViewForAdding(model: model) else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                accountCreation.controller,
                animated: true
            )
        }
    }
}
