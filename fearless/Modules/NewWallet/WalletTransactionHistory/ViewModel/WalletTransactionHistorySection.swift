import Foundation

class WalletTransactionHistorySection {
    let title: String
    var items: [WalletTransactionHistoryCellViewModel]

    init(title: String, items: [WalletTransactionHistoryCellViewModel]) {
        self.title = title
        self.items = items
    }
}
