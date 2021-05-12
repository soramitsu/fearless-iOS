import Foundation
import SoraFoundation

final class ControllerAccountWireframe: ControllerAccountWireframeProtocol {
    func showConfirmation(from _: ControllerBackedProtocol?) {
        // TODO:
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
