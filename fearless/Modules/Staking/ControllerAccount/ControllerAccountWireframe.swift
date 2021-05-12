import Foundation
import SoraFoundation

final class ControllerAccountWireframe: ControllerAccountWireframeProtocol {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        controllerAccountItem: AccountItem
    ) {
        guard let confirmation = ControllerAccountConfirmationViewFactory.createView(
            controllerAccountItem: controllerAccountItem
        ) else { return }
        view?.controller.navigationController?.pushViewController(confirmation.controller, animated: true)
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
