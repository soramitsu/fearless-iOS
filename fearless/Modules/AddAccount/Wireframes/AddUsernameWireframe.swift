import Foundation

final class AddUsernameWireframe: UsernameSetupWireframeProtocol {
    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory.createViewForAdding(username: username) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountCreation.controller,
                                                                  animated: true)
    }
}
