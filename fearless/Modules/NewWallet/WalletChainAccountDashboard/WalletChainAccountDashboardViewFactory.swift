import Foundation

struct WalletChainAccountDashboardViewFactory {
    static func createView(chain: ChainModel, asset: AssetModel) -> WalletChainAccountDashboardViewProtocol? {
        let interactor = WalletChainAccountDashboardInteractor()
        let wireframe = WalletChainAccountDashboardWireframe()

        let presenter = WalletChainAccountDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletChainAccountDashboardViewController(presenter: presenter)

        guard let selectedMetaAccount = SelectedWalletSettings.shared.value else {
            return nil
        }

        guard
            let accountListView = ChainAccountViewFactory.createView(chain: chain, asset: asset),
            let historyView = WalletTransactionHistoryViewFactory.createView(asset: asset, chain: chain, selectedAccount: selectedMetaAccount)
        else {
            return nil
        }

        view.content = accountListView
        view.draggable = historyView

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
