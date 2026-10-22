import Foundation
import UIKit

struct WalletConnectSessionViewModel {
    let dApp: String?
    let verification: String
    let verificationColor: UIColor?
    let warning: NSAttributedString?
    let walletViewModel: WalletsManagmentCellViewModel
    let messagePreview: String
    let signingRequest: WalletConnectSigningRequest
}
