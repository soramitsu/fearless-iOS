import Foundation

final class SoraCardInfoBoardRouter: SoraCardInfoBoardRouterInput {
    func presentTermsAndConditions(from view: SoraCardInfoBoardViewInput?) {
        guard let module = TermsAndConditionsAssembly.configureModule() else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func presentPreparation(from view: ControllerBackedProtocol?) {
        guard let module = PreparationAssembly.configureModule() else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
