import Foundation

struct PolkaswapQuoteParams: Equatable {
    let requestId: UUID
    let fromAssetId: String
    let toAssetId: String
    let amount: String
    let swapVariant: SwapVariant
    let liquiditySources: [String]
    let filterMode: PolkaswapLiquidityFilterMode

    init(
        requestId: UUID = UUID(),
        fromAssetId: String,
        toAssetId: String,
        amount: String,
        swapVariant: SwapVariant,
        liquiditySources: [String],
        filterMode: PolkaswapLiquidityFilterMode
    ) {
        self.requestId = requestId
        self.fromAssetId = fromAssetId
        self.toAssetId = toAssetId
        self.amount = amount
        self.swapVariant = swapVariant
        self.liquiditySources = liquiditySources
        self.filterMode = filterMode
    }

    static func == (lhs: PolkaswapQuoteParams, rhs: PolkaswapQuoteParams) -> Bool {
        lhs.requestId == rhs.requestId &&
            lhs.fromAssetId == rhs.fromAssetId &&
            lhs.toAssetId == rhs.toAssetId &&
            lhs.amount == rhs.amount &&
            lhs.swapVariant.rawValue == rhs.swapVariant.rawValue &&
            lhs.liquiditySources == rhs.liquiditySources &&
            lhs.filterMode.rawValue == rhs.filterMode.rawValue
    }
}
