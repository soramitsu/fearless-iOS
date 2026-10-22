import Foundation

struct WalletConnectSessionViewModel {
    let dApp: String?
    let warning: NSAttributedString?
    let walletViewModel: WalletsManagmentCellViewModel
    let messagePreview: String
    let signingRequest: WalletConnectSigningRequest
}
