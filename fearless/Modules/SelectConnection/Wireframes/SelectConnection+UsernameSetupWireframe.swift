import Foundation

extension SelectConnection {
    final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
        let connectionItem: ConnectionItem

        init(connectionItem: ConnectionItem) {
            self.connectionItem = connectionItem
        }

        func proceed(from view: UsernameSetupViewProtocol?, model: UsernameSetupModel) {
            guard let accountCreation = AccountCreateViewFactory
                .createViewForConnection(item: connectionItem, username: model.username)
            else {
                return
            }

            view?.controller.navigationController?.pushViewController(
                accountCreation.controller,
                animated: true
            )
        }
    }
}
