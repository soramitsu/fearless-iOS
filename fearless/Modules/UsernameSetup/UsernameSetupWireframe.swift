import Foundation

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountCreation.controller,
                                                                  animated: true)
    }
}
