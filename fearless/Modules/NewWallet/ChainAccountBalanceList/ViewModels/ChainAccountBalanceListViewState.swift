import Foundation

enum ChainAccountBalanceListViewState {
    case loading
    case loaded(viewModel: ChainAccountBalanceListViewModel)
    case error
}
