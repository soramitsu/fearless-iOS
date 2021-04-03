import Foundation
import CommonWallet

struct TransactionDetailsAccessoryViewModel: AccessoryViewModelProtocol {
    let title: String
    let amount: String
    let action: String
    let icon: UIImage?
    let command: WalletCommandProtocol
    let shouldAllowAction: Bool

    let numberOfLines: Int = 0

    init(
        title: String,
        amount: String,
        action: String,
        icon: UIImage?,
        command: WalletCommandProtocol,
        shouldAllowAction: Bool
    ) {
        self.title = title
        self.amount = amount
        self.action = action
        self.icon = icon
        self.command = command
        self.shouldAllowAction = shouldAllowAction
    }
}
