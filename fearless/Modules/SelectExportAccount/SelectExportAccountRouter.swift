import Foundation

final class SelectExportAccountRouter: SelectExportAccountRouterInput {
    func showWalletDetails(
        selectedWallet: MetaAccountModel,
        accountsInfo: [ChainAccountInfo],
        from view: ControllerBackedProtocol?
    ) {
        let viewController = WalletDetailsViewFactory.createView(flow: .export(
            wallet: selectedWallet,
            accounts: accountsInfo
        )).controller
        view?.controller.navigationController?.pushViewController(viewController, animated: true)
    }
}
