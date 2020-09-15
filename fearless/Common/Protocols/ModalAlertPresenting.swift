import UIKit

protocol ModalAlertPresenting {
    func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?)
}

extension ModalAlertPresenting {
    func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?) {
        let controller = ModalAlertFactory.createSuccessAlert(title)
        view?.controller.present(controller, animated: true, completion: nil)
    }
}
