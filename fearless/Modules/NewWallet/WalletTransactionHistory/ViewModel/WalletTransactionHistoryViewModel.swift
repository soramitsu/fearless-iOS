import Foundation

struct WalletTransactionHistoryViewModel {
    let sections: [WalletTransactionHistorySection]
    let lastChanges: [WalletTransactionHistoryChange]
    let filtersEnabled: Bool
}
