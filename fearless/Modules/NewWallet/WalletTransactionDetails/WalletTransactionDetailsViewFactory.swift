import Foundation

import SoraFoundation
import SSFModels

struct WalletTransactionDetailsViewFactory {
    static func createView(
        transaction: AssetTransactionData,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) -> WalletTransactionDetailsViewProtocol? {
        guard let address = selectedAccount.fetch(for: chain.accountRequest())?.toAddress() else {
            return nil
        }
        let interactor = WalletTransactionDetailsInteractor(transaction: transaction)
        let wireframe = WalletTransactionDetailsWireframe()

        let viewModelFactory = WalletTransactionDetailsViewModelFactory(accountAddress: address, assetBalanceFormatterFactory: AssetBalanceFormatterFactory(), asset: asset)
        let presenter = WalletTransactionDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            chain: chain
        )

        let view = WalletTransactionDetailsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
