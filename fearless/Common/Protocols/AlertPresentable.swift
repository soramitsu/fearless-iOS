import UIKit

struct AlertPresentableAction {
    enum Style {
        case normal
        case destructive
        case cancel
    }

    var title: String
    var handler: (() -> Void)?
    var style: Style

    init(title: String, style: Style = .normal, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
        self.style = style
    }

    init(title: String, style: Style = .normal) {
        self.title = title
        self.style = style
    }
}

struct AlertPresentableViewModel {
    let title: String?
    let message: String?
    let actions: [AlertPresentableAction]
    let closeAction: String?
}

protocol AlertPresentable: class {
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?)

    func present(viewModel: AlertPresentableViewModel,
                 style: UIAlertController.Style,
                 from view: ControllerBackedProtocol?)
}

extension AlertPresentableAction.Style {
    var uialertStyle: UIAlertAction.Style {
        switch self {
        case .normal:
            return .default
        case .cancel:
            return .cancel
        case .destructive:
            return .destructive
        }
    }
}

extension AlertPresentable {
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        UIAlertController.present(message: message,
                                  title: title,
                                  closeAction: closeAction,
                                  with: controller)
    }

    func present(viewModel: AlertPresentableViewModel,
                 style: UIAlertController.Style,
                 from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alertView = UIAlertController(title: viewModel.title,
                                          message: viewModel.message,
                                          preferredStyle: style)

        viewModel.actions.forEach { action in
            let alertAction = UIAlertAction(title: action.title, style: action.style.uialertStyle) { _ in
                action.handler?()
            }

            alertView.addAction(alertAction)
        }

        if let closeAction = viewModel.closeAction {
            let action = UIAlertAction(title: closeAction,
                                       style: .cancel,
                                       handler: nil)
            alertView.addAction(action)
        }

        controller.present(alertView, animated: true, completion: nil)
    }
}

extension UIAlertController {
    public static func present(message: String?, title: String?,
                               closeAction: String?, with presenter: UIViewController) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: closeAction, style: .cancel, handler: nil)
        alertView.addAction(action)
        presenter.present(alertView, animated: true, completion: nil)
    }
}
