import Foundation

struct CrossChainConfirmationViewModel {
    let symbolViewModel: SymbolViewModel
    let originalNetworkName: String
    let destNetworkName: String
    let amount: BalanceViewModelProtocol
    let originalChainFee: BalanceViewModelProtocol
    let destChainFee: BalanceViewModelProtocol
}
