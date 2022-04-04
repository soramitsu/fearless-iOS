import Foundation

struct ChainAccountInfo {
    let chain: ChainModel
    let account: ChainAccountResponse
}

final class SelectExportAccountRouter: SelectExportAccountRouterInput {
    func showWalletDetails(
        selectedWallet: MetaAccountModel,
        accountInfo _: [ChainAccountInfo],
        from view: ControllerBackedProtocol?
    ) {
        let viewController = WalletDetailsViewFactory.createView(with: selectedWallet).controller
        view?.controller.navigationController?.pushViewController(viewController, animated: true)
    }
}
