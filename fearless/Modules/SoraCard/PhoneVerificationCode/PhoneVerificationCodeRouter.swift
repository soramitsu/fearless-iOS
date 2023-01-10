import Foundation

final class PhoneVerificationCodeRouter: PhoneVerificationCodeRouterInput {
    func presentIntroduce(from view: PhoneVerificationCodeViewInput?, phone: String) {
        guard let module = IntroduceAssembly.configureModule(with: phone) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: PhoneVerificationCodeViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
