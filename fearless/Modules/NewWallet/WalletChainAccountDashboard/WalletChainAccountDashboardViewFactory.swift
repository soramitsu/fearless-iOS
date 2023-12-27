import Foundation
import SSFModels

struct WalletChainAccountDashboardViewFactory {
    static func createDetailsView(
        chainAsset: ChainAsset
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
                moduleOutput: presenter,
                mode: .extended
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

    static func createNetworksView(
        chainAsset: ChainAsset
    ) -> WalletChainAccountDashboardViewProtocol? {
        let interactor = WalletChainAccountDashboardInteractor()
        let wireframe = WalletChainAccountDashboardWireframe()

        let presenter = WalletChainAccountDashboardPresenter(interactor: interactor, wireframe: wireframe)

        let view = WalletChainAccountDashboardViewController(presenter: presenter)

        guard
            let wallet = SelectedWalletSettings.shared.value,
            let networksModule = AssetNetworksAssembly.configureModule(
                chainAsset: chainAsset,
                wallet: wallet
            ),
            let balanceInfoModule = ChainAccountViewFactory.createView(
                chainAsset: chainAsset,
                wallet: wallet,
                moduleOutput: presenter,
                mode: .simple
            )
        else {
            return nil
        }

        view.content = balanceInfoModule.view
        view.draggable = networksModule.view

        presenter.assetNetworksModuleInput = networksModule.input
        presenter.chainAccountModuleInput = balanceInfoModule.moduleInput

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
