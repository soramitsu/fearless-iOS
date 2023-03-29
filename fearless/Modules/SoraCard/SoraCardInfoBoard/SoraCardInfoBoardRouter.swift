import Foundation

final class SoraCardInfoBoardRouter: SoraCardInfoBoardRouterInput {
    func start(from view: SoraCardInfoBoardViewInput?, data: SCKYCUserDataModel, wallet: MetaAccountModel) {
        guard let module = KYCMainAssembly.configureModule(data: data, wallet: wallet) else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)
    }

    func showVerificationStatus(from view: SoraCardInfoBoardViewInput?) {
        guard let module = VerificationStatusAssembly.configureModule() else {
            return
        }
        let navigationController = FearlessNavigationController(rootViewController: module.view.controller)

        view?.controller.present(navigationController, animated: true)
    }
}
