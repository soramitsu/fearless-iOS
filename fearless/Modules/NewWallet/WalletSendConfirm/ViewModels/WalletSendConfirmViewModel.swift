import Foundation

struct WalletSendConfirmViewModel {
    let networkName: String
    let networkIsTestnet: Bool
    let networkIcon: ImageViewModelProtocol?
    let amountAttributedString: NSAttributedString
    let amountString: String
    let senderNameString: String
    let senderAddressString: String
    let receiverAddressString: String
    let priceString: String
    let feeAmountString: String
    let feePriceString: String
    let tipRequired: Bool
    let tipAmountString: String
    let tipPriceString: String
    let showWarning: Bool
    let symbolViewModel: SymbolViewModel
    /// The deposit that opens the recipient's Solana token account, included in the fee; empty
    /// when the transfer opens no account.
    var accountCreationAmountString: String = ""
    var accountCreationPriceString: String = ""
}
