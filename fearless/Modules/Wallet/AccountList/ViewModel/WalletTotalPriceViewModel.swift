import Foundation
import CommonWallet

final class WalletTotalPriceViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String { WalletAccountListConstants.totalPriceIdentifier }
    var itemHeight: CGFloat { WalletAccountListConstants.height }

    let title: String
    let price: String

    let command: WalletCommandProtocol?
    let accountCommand: WalletCommandProtocol?

    init(title: String,
         price: String,
         accountCommand: WalletCommandProtocol?,
         command: WalletCommandProtocol?) {
        self.title = title
        self.price = price
        self.accountCommand = accountCommand
        self.command = command
    }
}
