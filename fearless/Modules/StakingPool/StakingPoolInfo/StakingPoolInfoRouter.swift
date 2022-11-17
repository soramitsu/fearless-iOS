import Foundation

final class StakingPoolInfoRouter: StakingPoolInfoRouterInput {
    func proceedToSelectValidatorsStart(
        from view: ControllerBackedProtocol?,
        poolId _: UInt32,
        state _: ExistingBonding,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let validatorsView = YourValidatorListViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .pool
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(validatorsView.controller, animated: true)
    }

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

    func showUpdateRoles(
        roles: StakingPoolRoles,
        poolId: String,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let updateRolesView = PoolRolesConfirmAssembly.configureModule(
            chainAsset: chainAsset,
            wallet: wallet,
            poolId: poolId,
            roles: roles
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(updateRolesView.view.controller, animated: true)
    }
}
