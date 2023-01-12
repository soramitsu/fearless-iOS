import Foundation

final class IntroduceRouter: IntroduceRouterInput {
    func presentVerificationEmail(
        from view: IntroduceViewInput?,
        data: SCKYCUserDataModel
    ) {
        guard let module = EmailVerificationAssembly.configureModule(with: data) else {
            return
        }
        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func close(from view: IntroduceViewInput?) {
        view?.controller.dismiss(animated: true)
    }
}
