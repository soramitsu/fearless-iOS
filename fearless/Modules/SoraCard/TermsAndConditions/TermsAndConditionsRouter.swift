import Foundation

final class TermsAndConditionsRouter: TermsAndConditionsRouterInput {
    func presentPhoneVerification(from view: TermsAndConditionsViewInput?) {
        guard let module = PhoneVerificationAssembly.configureModule() else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
