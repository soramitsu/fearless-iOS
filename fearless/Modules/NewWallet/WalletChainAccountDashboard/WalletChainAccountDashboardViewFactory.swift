import Foundation

struct WalletChainAccountDashboardViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        chainAssets _: [ChainAsset]
    ) -> WalletChainAccountDashboardViewProtocol? {
        let interactor = WalletChainAccountDashboardInteractor()
        let wireframe = WalletChainAccountDashboardWireframe()

        let presenter = WalletChainAccountDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletChainAccountDashboardViewController(presenter: presenter)

        guard
            let wallet = SelectedWalletSettings.shared.value,
            let historyModule = WalletTransactionHistoryViewFactory.createView(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                selectedAccount: wallet
            ),
            let chainAccountModule = ChainAccountViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
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
