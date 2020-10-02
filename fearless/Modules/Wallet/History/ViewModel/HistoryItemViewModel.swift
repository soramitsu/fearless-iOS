import Foundation
import CommonWallet

final class HistoryItemViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String { HistoryConstants.historyCellId }
    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: String
    let details: String
    let amount: String
    let direction: TransactionType
    let status: AssetTransactionStatus
    let imageViewModel: WalletImageViewModelProtocol?
    let command: WalletCommandProtocol?

    init(title: String,
         details: String,
         amount: String,
         direction: TransactionType,
         status: AssetTransactionStatus,
         imageViewModel: WalletImageViewModelProtocol?,
         command: WalletCommandProtocol?) {
        self.title = title
        self.details = details
        self.amount = amount
        self.direction = direction
        self.status = status
        self.imageViewModel = imageViewModel
        self.command = command
    }
}
