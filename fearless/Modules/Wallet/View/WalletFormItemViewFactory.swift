import Foundation
import CommonWallet

final class WalletFormItemViewFactory: WalletFormItemViewFactoryOverriding {
    func createTokenView() -> (WalletFormItemView & WalletFormTokenViewProtocol)? {
        let view = R.nib.walletTokenView(owner: nil)!
        return view
    }
}
