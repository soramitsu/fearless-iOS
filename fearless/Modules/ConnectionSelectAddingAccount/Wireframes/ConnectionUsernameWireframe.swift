import Foundation

final class ConnectionUsernameWireframe: UsernameSetupWireframeProtocol {
    let connectionItem: ConnectionItem

    init(connectionItem: ConnectionItem) {
        self.connectionItem = connectionItem
    }

    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accountCreation = AccountCreateViewFactory
            .createViewForConnection(item: connectionItem, username: username) else {
            return
        }

        view?.controller.navigationController?.pushViewController(accountCreation.controller,
                                                                  animated: true)
    }
}
