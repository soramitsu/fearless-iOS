import Foundation

struct WalletChainAccountDashboardViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        availableChainAssets: [ChainAsset]
    ) -> WalletChainAccountDashboardViewProtocol? {
        let interactor = WalletChainAccountDashboardInteractor()
        let wireframe = WalletChainAccountDashboardWireframe()

        let presenter = WalletChainAccountDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletChainAccountDashboardViewController(presenter: presenter)

        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let historyModule = WalletTransactionHistoryViewFactory.createView(
                asset: chainAsset.asset,
                chain: chainAsset.chain,
                selectedAccount: selectedMetaAccount
            ),
            let chainAccountModule = ChainAccountViewFactory.createView(
                chainAsset: chainAsset,
                selectedMetaAccount: selectedMetaAccount,
                moduleOutput: presenter,
                availableChainAssets: availableChainAssets
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
