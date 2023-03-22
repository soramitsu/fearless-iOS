import Foundation

final class SCKYCTermsAndConditionsRouter: SCKYCTermsAndConditionsRouterInput {
    func presentPhoneVerification(from view: ControllerBackedProtocol?) {
        guard let module = PhoneVerificationAssembly.configureModule() else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
