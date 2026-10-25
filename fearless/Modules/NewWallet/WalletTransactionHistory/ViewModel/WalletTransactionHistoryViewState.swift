import Foundation

enum WalletTransactionHistoryViewState {
    case loading
    case loaded(viewModel: WalletTransactionHistoryViewModel)
    case reloaded(viewModel: WalletTransactionHistoryViewModel)
    case unsupported
    case unavailable
    /// The app has no rows for this wallet on a network whose full history is on its public
    /// explorer (Solana): the explorer link is offered instead of an empty list.
    case explorerOnly
}
