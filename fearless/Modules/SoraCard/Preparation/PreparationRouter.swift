import Foundation

final class PreparationRouter: PreparationRouterInput {
    func presentKYC(from view: ControllerBackedProtocol?) {
        guard let module = KYCOnboardingAssembly.configureModule() else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
