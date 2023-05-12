import Foundation

struct CrossChainConfirmationViewModel {
    let sendTo: String
    let doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel
    let originalNetworkName: String
    let destNetworkName: String
    let amount: String
    let originalChainFee: BalanceViewModelProtocol
    let destChainFee: BalanceViewModelProtocol
}
