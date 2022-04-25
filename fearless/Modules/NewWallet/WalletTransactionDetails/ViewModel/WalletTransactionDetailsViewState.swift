import Foundation

enum WalletTransactionDetailsViewState {
    case loading
    case loaded(viewModel: WalletTransactionDetailsViewModel)
    case empty
}
