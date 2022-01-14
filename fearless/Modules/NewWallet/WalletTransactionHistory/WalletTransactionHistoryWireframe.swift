import Foundation
import CommonWallet

final class WalletTransactionHistoryWireframe: WalletTransactionHistoryWireframeProtocol {
    func showTransactionDetails(
        from view: ControllerBackedProtocol?,
        transaction: AssetTransactionData,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let controller = WalletTransactionDetailsViewFactory.createView(transaction: transaction, asset: asset, chain: chain, selectedAccount: selectedAccount)?.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }
}
