import Foundation

struct WalletConnectConfirmationViewModel {
    let symbolViewModel: SymbolViewModel
    let method: String
    let amount: String?
    let walletName: String
    let dApp: String
    let host: String
    let chain: String
    let rawData: NSAttributedString
}
