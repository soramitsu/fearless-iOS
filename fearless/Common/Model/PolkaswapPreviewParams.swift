import Foundation

struct PolkaswapPreviewParams {
    let wallet: MetaAccountModel
    let soraChinAsset: ChainAsset
    let swapFromChainAsset: ChainAsset
    let swapToChainAsset: ChainAsset
    let fromAmount: Decimal
    let toAmount: Decimal
    let slippadgeTolerance: Float
    let swapVariant: SwapVariant
    let market: LiquiditySourceType
    let polkaswapDexForRoute: PolkaswapDex
    let networkFee: BalanceViewModelProtocol
    let detailsViewModel: PolkaswapAdjustmentDetailsViewModel
    let minMaxValue: Decimal
}
