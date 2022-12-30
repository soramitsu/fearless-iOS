import Foundation

struct WalletSendConfirmViewModel {
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
}
