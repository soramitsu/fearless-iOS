import Foundation
import CommonWallet

protocol WalletFearlessFormDefining: WalletFormDefining {
    func defineViewForFearlessTokenViewModel(_ model: WalletTokenViewModel) -> WalletFormItemView?
    func defineViewForCompoundDetails(_ viewModel: WalletCompoundDetailsViewModel) -> WalletFormItemView?
    func defineViewForAmountDisplay(_ viewModel: RichAmountDisplayViewModel) -> WalletFormItemView?
}
