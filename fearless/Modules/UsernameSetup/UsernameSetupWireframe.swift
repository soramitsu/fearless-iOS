import Foundation

final class UsernameSetupWireframe: UsernameSetupWireframeProtocol {
    func proceed(from view: UsernameSetupViewProtocol?, username: String) {
        guard let accessBackup = AccessBackupViewFactory.createView() else {
            return
        }

        view?.controller.navigationController?.pushViewController(accessBackup.controller,
                                                                  animated: true)
    }
}
