import Foundation
import CommonWallet

struct TransferConfirmAccessoryViewModel: AccessoryViewModelProtocol {
    let title: String
    let icon: UIImage?
    let action: String
    let numberOfLines: Int
    let amount: String
}
