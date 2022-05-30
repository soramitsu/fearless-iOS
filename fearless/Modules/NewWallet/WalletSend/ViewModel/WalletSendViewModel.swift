import Foundation
import CommonWallet

struct WalletSendViewModel {
    let accountViewModel: AccountViewModel?
    let assetBalanceViewModel: AssetBalanceViewModelProtocol?
    let tipRequired: Bool
    let tipViewModel: BalanceViewModelProtocol?
    let feeViewModel: BalanceViewModelProtocol?
    let amountInputViewModel: AmountInputViewModelProtocol?
}
