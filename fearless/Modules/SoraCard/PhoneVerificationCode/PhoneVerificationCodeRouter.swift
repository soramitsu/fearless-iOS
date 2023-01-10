import Foundation

final class PhoneVerificationCodeRouter: PhoneVerificationCodeRouterInput {
    func presentIntroduce(from view: PhoneVerificationCodeViewInput?, data: SCKYCUserDataModel) {
        guard let module = IntroduceAssembly.configureModule(with: data) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: PhoneVerificationCodeViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
