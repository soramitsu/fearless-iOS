import Foundation

final class SoraCardInfoBoardRouter: SoraCardInfoBoardRouterInput {
    func startKYC(from view: SoraCardInfoBoardViewInput?, data: SCKYCUserDataModel, wallet: MetaAccountModel) {
        guard let module = KYCMainAssembly.configureModule(data: data, wallet: wallet) else {
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
