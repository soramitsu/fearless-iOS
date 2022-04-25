import Foundation

protocol Dismissable: AnyObject {
    func dismiss(view: ControllerBackedProtocol?)
}

protocol PushDismissable: Dismissable {}

protocol PresentDismissable: Dismissable {}

extension PushDismissable {
    func dismiss(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }
}

extension PresentDismissable {
    func dismiss(view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
