import Foundation

final class EmailVerificationRouter: EmailVerificationRouterInput {
    func presentPreparation(from view: EmailVerificationViewInput?) {
        guard let module = PreparationAssembly.configureModule() else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
