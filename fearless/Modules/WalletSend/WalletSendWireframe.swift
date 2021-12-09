import Foundation

final class WalletSendWireframe: WalletSendWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}
