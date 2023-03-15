import Foundation

final class EmailVerificationRouter: EmailVerificationRouterInput {
    func presentPreparation(from view: EmailVerificationViewInput?) {
        guard let module = PreparationAssembly.configureModule() else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: EmailVerificationViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
