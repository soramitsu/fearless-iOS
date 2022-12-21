import Foundation
import BigInt
import SoraFoundation

protocol SwapQuoteConverterProtocol {
    func createAmounts(
        xorChainAsset: ChainAsset,
        fromAsset: AssetModel?,
        toAsset: AssetModel?,
        params: PolkaswapQuoteParams,
        quote: [SwapValues],
        locale: Locale
    ) -> SwapQuoteAmounts?
}

struct SwapQuoteAmounts {
    let bestQuote: SubstrateSwapValues
    let fromAmount: Decimal
    let toAmount: Decimal
    let lpAmount: Decimal
}

class SwapQuoteAmountsFactory: SwapQuoteConverterProtocol {
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    init(assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func createAmounts(
        xorChainAsset: ChainAsset,
        fromAsset: AssetModel?,
        toAsset: AssetModel?,
        params: PolkaswapQuoteParams,
        quote: [SwapValues],
        locale _: Locale
    ) -> SwapQuoteAmounts? {
        let subsctrateSwapValues: [SubstrateSwapValues] = quote.compactMap { quote -> SubstrateSwapValues? in
            guard let toAmountBig = BigUInt(quote.amount),
                  let feeBig = BigUInt(quote.fee)
            else {
                return nil
            }
            return SubstrateSwapValues(
                dexId: quote.dexId,
                amount: toAmountBig,
                fee: feeBig,
                rewards: quote.rewards
            )
        }
        guard let bestQuote = subsctrateSwapValues.sorted(by: {
            $0.amount > $1.amount
        }).first else {
            return nil
        }

        guard
            let fromAmountBig = BigUInt(params.amount),
            let fromAssetPrecision = fromAsset?.precision,
            let toAssetPrecision = toAsset?.precision,
            let fromAmount = Decimal.fromSubstrateAmount(fromAmountBig, precision: Int16(fromAssetPrecision)),
            let toAmount = Decimal.fromSubstrateAmount(bestQuote.amount, precision: Int16(toAssetPrecision)),
            let lpAmount = Decimal.fromSubstrateAmount(bestQuote.fee, precision: Int16(xorChainAsset.asset.precision))
        else {
            return nil
        }

        return SwapQuoteAmounts(
            bestQuote: bestQuote,
            fromAmount: fromAmount,
            toAmount: toAmount,
            lpAmount: lpAmount
        )
    }
}
