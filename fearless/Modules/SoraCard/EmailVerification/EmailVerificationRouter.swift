import Foundation

final class EmailVerificationRouter: EmailVerificationRouterInput {
    func presentPreparation(from view: EmailVerificationViewInput?, data: SCKYCUserDataModel) {
        guard let module = PreparationAssembly.configureModule(data: data) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: ControllerBackedProtocol?) {
        view?.controller.dismiss(animated: true)
    }
}
