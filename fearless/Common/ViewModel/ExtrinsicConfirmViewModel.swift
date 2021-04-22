import Foundation
import CommonWallet

struct ExtrinisicConfirmViewModel: AccessoryViewModelProtocol {
    let title: String
    let amount: String
    let price: String?
    let icon: UIImage?
    let action: String
    let numberOfLines: Int
    let shouldAllowAction: Bool
}
