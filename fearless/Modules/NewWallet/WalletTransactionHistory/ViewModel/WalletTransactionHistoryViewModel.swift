import Foundation

enum WalletTransactionHistoryViewFilterMode {
    case single
    case multiple
    case disabled
}

struct WalletTransactionHistoryViewModel {
    let sections: [WalletTransactionHistorySection]
    let lastChanges: [WalletTransactionHistoryChange]
    let filtering: WalletTransactionHistoryViewFilterMode
}
