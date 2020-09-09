import Foundation

final class AccountInfoWireframe: AccountInfoWireframeProtocol {
    func close(view: AccountInfoViewProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    func showExport(for accountId: String, from view: AccountInfoViewProtocol?) {
        // TODO: FLW-89
    }
}
