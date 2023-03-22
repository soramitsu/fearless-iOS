import Foundation

final class PhoneVerificationRouter: PhoneVerificationRouterInput {
    func presentVerificationCode(from view: PhoneVerificationViewInput?, data: SCKYCUserDataModel, otpLength: Int) {
        guard let module = PhoneVerificationCodeAssembly.configureModule(with: data, otpLength: otpLength) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: PhoneVerificationViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
