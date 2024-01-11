import Foundation

struct PolkaswapSwapConfirmationViewModel {
    let amountsText: NSAttributedString
    let doubleImageViewViewModel: PolkaswapDoubleSymbolViewModel
    let adjustmentDetailsViewModel: PolkaswapAdjustmentDetailsViewModel
    let networkFee: BalanceViewModelProtocol
    let minMaxTitle: String
}
