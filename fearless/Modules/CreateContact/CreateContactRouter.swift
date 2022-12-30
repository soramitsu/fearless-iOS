import Foundation

final class CreateContactRouter: CreateContactRouterInput {
    func showSelectNetwork(
        from view: CreateContactViewInput?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        delegate: SelectNetworkDelegate?
    ) {
        guard
            let module = SelectNetworkAssembly.configureModule(
                wallet: wallet,
                selectedChainId: selectedChainId,
                chainModels: nil,
                includingAllNetworks: false,
                searchTextsViewModel: nil,
                delegate: delegate
            )
        else {
            return
        }

        view?.controller.present(module.view.controller, animated: true)
    }
}
