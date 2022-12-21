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
    let minMaxReceive: BalanceViewModelProtocol
    let polkaswapDexForRoute: PolkaswapDex
    let lpFee: BalanceViewModelProtocol
    let networkFee: BalanceViewModelProtocol
}
