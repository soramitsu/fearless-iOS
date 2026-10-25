import Foundation

final class AssetManagementRouter: AssetManagementRouterInput {
    func presentResetOrderConfirmation(viewModel: SheetAlertPresentableViewModel, from view: ControllerBackedProtocol?) {
        guard let controller = view?.controller, controller.presentedViewController == nil,
              viewModel.actions.count == 1, viewModel.closeAction != nil else { return }
        controller.present(AssetManagementResetOrderViewController(viewModel: viewModel), animated: true)
    }

    func showSelectNetwork(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        delegate: NetworkManagmentModuleOutput?
    ) {
        guard
            let module = NetworkManagmentAssembly.configureModule(
                wallet: wallet,
                chains: nil,
                contextTag: nil,
                moduleOutput: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
