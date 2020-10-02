import Foundation
import CommonWallet

enum HistoryItemViewModelDirection {
    case incoming
    case outgoing
}

enum HistoryItemViewModelStatus {
    case completed
    case failed
    case pending
}

final class HistoryItemViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String { HistoryConstants.historyCellId }
    var itemHeight: CGFloat { HistoryConstants.historyHeight }

    let title: String
    let details: String
    let amount: String
    let direction: HistoryItemViewModelDirection
    let status: HistoryItemViewModelStatus
    let imageViewModel: WalletImageViewModelProtocol
    let command: WalletCommandProtocol?

    init(title: String,
         details: String,
         amount: String,
         direction: HistoryItemViewModelDirection,
         status: HistoryItemViewModelStatus,
         imageViewModel: WalletImageViewModelProtocol,
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
