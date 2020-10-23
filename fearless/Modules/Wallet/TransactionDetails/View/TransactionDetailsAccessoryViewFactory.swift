import Foundation
import CommonWallet

final class TransactionDetailsAccessoryViewFactory: CommonWallet.AccessoryViewFactoryProtocol {
    static func createAccessoryView(from type: WalletAccessoryViewType,
                                    style: WalletAccessoryStyleProtocol?,
                                    target: Any?,
                                    completionSelector: Selector?) -> CommonWallet.AccessoryViewProtocol {
        R.nib.transactionDetailsAccessoryView(owner: nil)!
    }
}
