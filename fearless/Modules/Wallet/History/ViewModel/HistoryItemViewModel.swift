import Foundation
import CommonWallet

final class HistoryItemViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String { HistoryConstants.historyCellId }
    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: String
    let subtitle: String
    let time: String
    let amount: String
    let type: TransactionType
    let status: AssetTransactionStatus
    let imageViewModel: WalletImageViewModelProtocol?
    let command: WalletCommandProtocol?

    init(
        title: String,
        subtitle: String,
        amount: String,
        time: String,
        type: TransactionType,
        status: AssetTransactionStatus,
        imageViewModel: WalletImageViewModelProtocol?,
        command: WalletCommandProtocol?
    ) {
        self.title = title
        self.subtitle = subtitle
        self.amount = amount
        self.time = time
        self.type = type
        self.status = status
        self.imageViewModel = imageViewModel
        self.command = command
    }
}
