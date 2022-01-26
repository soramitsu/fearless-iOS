import Foundation

final class WalletTransactionDetailsWireframe: WalletTransactionDetailsWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
