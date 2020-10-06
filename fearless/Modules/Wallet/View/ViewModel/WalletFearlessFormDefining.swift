import Foundation
import CommonWallet

protocol WalletFearlessFormDefining: WalletFormDefining {
    func defineViewForFearlessTokenViewModel(_ model: WalletTokenViewModel) -> WalletFormItemView?
    func defineViewForFearlessAccountViewModel(_ model: WalletAccountViewModel) -> WalletFormItemView?
}
