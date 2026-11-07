import Foundation

struct WalletConnectSessionViewModel {
    let dApp: String?
    let warning: NSAttributedString?
    let walletViewModel: WalletsManagmentCellViewModel
    let payload: WalletConnectPayload
    let wallet: MetaAccountModel
}
