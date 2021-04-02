import Foundation
import CommonWallet

final class TransactionDetailsAccessoryViewFactory: CommonWallet.AccessoryViewFactoryProtocol {
    static func createAccessoryView(
        from _: WalletAccessoryViewType,
        style _: WalletAccessoryStyleProtocol?,
        target _: Any?,
        completionSelector _: Selector?
    ) -> CommonWallet.AccessoryViewProtocol {
        R.nib.transactionDetailsAccessoryView(owner: nil)!
    }
}
