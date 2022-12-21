import Foundation

struct PolkaswapSwapConfirmationViewModel {
    let amountsText: NSAttributedString
    let doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel
    let fromPerToTitle: String
    let toPerFromTitle: String
    let fromPerToPrice: String
    let toPerFromPrice: String
    let minMaxReceive: BalanceViewModelProtocol
    let swapRoute: NSAttributedString
    let liquitityProviderFee: BalanceViewModelProtocol
    let networkFee: BalanceViewModelProtocol
}
