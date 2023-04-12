import Foundation

final class KYCOnboardingRouter: KYCOnboardingRouterInput {
    func showStatus(from view: ControllerBackedProtocol) {
        guard let module = VerificationStatusAssembly.configureModule() else {
            return
        }
        view.controller.navigationController?.pushViewController(
            module.view.controller,
            animated: true
        )
    }
}
