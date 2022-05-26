import Foundation

struct WalletSendConfirmViewModel {
    let amountString: String
    let senderAccountViewModel: AccountViewModel?
    let receiverAccountViewModel: AccountViewModel?
    let assetBalanceViewModel: AssetBalanceViewModelProtocol?
    let tipRequired: Bool
    let tipViewModel: BalanceViewModelProtocol?
    let feeViewModel: BalanceViewModelProtocol?
}
