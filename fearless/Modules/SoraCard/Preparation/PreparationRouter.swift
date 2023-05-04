import Foundation

final class PreparationRouter: PreparationRouterInput {
    func presentKYC(from view: ControllerBackedProtocol?, data: SCKYCUserDataModel) {
        guard let module = KYCOnboardingAssembly.configureModule(data: data) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }
}
