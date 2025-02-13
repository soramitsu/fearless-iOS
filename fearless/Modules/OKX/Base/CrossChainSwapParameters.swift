import SSFModels
import Foundation

struct CrossChainSwapParameters {
    let swapFromChainAsset: ChainAsset
    let swapToChainAsset: ChainAsset
    let wallet: MetaAccountModel
    let amount: String
    let selectedDexIds: [String]?
    let swap: CrossChainSwap
    let slippage: Decimal
}
