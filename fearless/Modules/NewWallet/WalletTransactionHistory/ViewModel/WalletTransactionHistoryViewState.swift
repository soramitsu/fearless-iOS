import Foundation

enum WalletTransactionHistoryViewState {
    case loading
    case loaded(viewModel: WalletTransactionHistoryViewModel)
    case reloaded(viewModel: WalletTransactionHistoryViewModel)
}
