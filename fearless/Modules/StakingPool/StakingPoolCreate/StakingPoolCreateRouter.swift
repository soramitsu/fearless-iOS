import Foundation

final class StakingPoolCreateRouter: StakingPoolCreateRouterInput {
    func showWalletManagment(
        contextTag: Int,
        from view: ControllerBackedProtocol?,
        moduleOutput: WalletsManagmentModuleOutput?
    ) {
        let module = WalletsManagmentAssembly.configureModule(
            shouldSaveSelected: false,
            contextTag: contextTag,
            moduleOutput: moduleOutput
        )

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func showConfirm(
        from view: ControllerBackedProtocol?,
        with createData: StakingPoolCreateData
    ) {
        let module = StakingPoolCreateConfirmAssembly.configureModule(with: createData)

        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(controller, animated: true)
    }
}
