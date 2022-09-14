import Foundation
import CommonWallet

struct WalletSendViewModel {
    let assetBalanceViewModel: AssetBalanceViewModelProtocol?
    let tipRequired: Bool
    let tipViewModel: BalanceViewModelProtocol?
    let feeViewModel: BalanceViewModelProtocol?
    let amountInputViewModel: AmountInputViewModelProtocol?
    let scamInfo: ScamInfo?
}
