import Foundation

struct SwapTransactionViewModel {
    let doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel
    let amountsText: NSAttributedString
    let status: NSAttributedString
    let address: String
    let date: String
    let networkFee: BalanceViewModelProtocol
}
