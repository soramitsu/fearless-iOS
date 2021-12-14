import Foundation
import CommonWallet

struct WalletSendViewModel {
    let accountViewModel: AccountViewModel?
    let assetBalanceViewModel: AssetBalanceViewModelProtocol?
    let feeViewModel: BalanceViewModelProtocol?
    let amountInputViewModel: AmountInputViewModelProtocol?
}
