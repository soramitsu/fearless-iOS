import Foundation

enum ChainAccountViewState {
    case loading
    case loaded(ChainAccountViewModel)
    case error
}
