import Foundation

struct WalletChainAccountDashboardViewFactory {
    static func createView(chain: ChainModel, asset: AssetModel) -> WalletChainAccountDashboardViewProtocol? {
        let interactor = WalletChainAccountDashboardInteractor()
        let wireframe = WalletChainAccountDashboardWireframe()

        let presenter = WalletChainAccountDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletChainAccountDashboardViewController(presenter: presenter)

        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let historyModule = WalletTransactionHistoryViewFactory.createView(
                asset: asset,
                chain: chain,
                selectedAccount: selectedMetaAccount
            ),
            let chainAccountModule = ChainAccountViewFactory.createView(
                chain: chain,
                asset: asset,
                selectedMetaAccount: selectedMetaAccount,
                moduleOutput: presenter
            )
        else {
            return nil
        }

        view.content = chainAccountModule.view
        view.draggable = historyModule.view

        presenter.transactionHistoryModuleInput = historyModule.moduleInput
        presenter.chainAccountModuleInput = chainAccountModule.moduleInput

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
