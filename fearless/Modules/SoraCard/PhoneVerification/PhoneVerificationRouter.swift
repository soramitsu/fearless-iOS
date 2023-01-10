import Foundation

final class PhoneVerificationRouter: PhoneVerificationRouterInput {
    func presentVerificationCode(from view: PhoneVerificationViewInput?, phone: String) {
        guard let module = PhoneVerificationCodeAssembly.configureModule(with: phone) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: PhoneVerificationViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
