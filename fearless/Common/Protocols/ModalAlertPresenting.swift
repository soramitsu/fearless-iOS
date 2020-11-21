import UIKit

protocol ModalAlertPresenting {
    func presentSuccessNotification(_ title: String,
                                    from view: ControllerBackedProtocol?,
                                    completion closure: (() -> Void)?)
}

extension ModalAlertPresenting {
    func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?) {
        presentSuccessNotification(title, from: view, completion: nil)
    }

    func presentSuccessNotification(_ title: String,
                                    from view: ControllerBackedProtocol?,
                                    completion closure: (() -> Void)?) {
        let controller = ModalAlertFactory.createSuccessAlert(title)
        view?.controller.present(controller, animated: true, completion: closure)
    }
}
