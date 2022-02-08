import UIKit

final class CheckPincodeWireframe: CheckPincodeWireframeProtocol {
    let targetView: UIViewController?
    let presentationStyle: PresentationStyle

    init(targetView: UIViewController? = nil, presentationStyle: PresentationStyle = .present) {
        self.targetView = targetView
        self.presentationStyle = presentationStyle
    }

    func finishCheck(from view: ControllerBackedProtocol?) {
        if let target = targetView, view?.controller.navigationController != nil {
            view?.controller.navigationController?.pushViewController(target, animated: true)
        } else {
            close(from: view)
        }
    }
}

private extension CheckPincodeWireframe {
    func close(from view: ControllerBackedProtocol?) {
        switch presentationStyle {
        case .present:
            view?.controller.dismiss(animated: true)
        case .push:
            view?.controller.navigationController?.popViewController(animated: true)
        }
    }
}
