import Foundation

final class EmailVerificationRouter: EmailVerificationRouterInput {
    func presentPreparation(from view: EmailVerificationViewInput?, data: SCKYCUserDataModel) {
        guard let module = PreparationAssembly.configureModule(with: data) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: EmailVerificationViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
