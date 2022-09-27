import Foundation

protocol Dismissable: AnyObject {
    func dismiss(view: ControllerBackedProtocol?)
}

protocol PushDismissable: Dismissable {}

protocol PresentDismissable: Dismissable {}

protocol AnyDismissable: Dismissable {}

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

extension AnyDismissable {
    func dismiss(view: ControllerBackedProtocol?) {
        if view?.controller.navigationController?.visibleViewController != view?.controller.navigationController?.viewControllers.first {
            view?.controller.navigationController?.popViewController(animated: true)
        } else {
            view?.controller.dismiss(animated: true)
        }
    }
}
