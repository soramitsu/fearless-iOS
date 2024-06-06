import Foundation
import SSFPolkaswap
import SSFPools
import SSFModels

protocol LiquidityPoolSupplyViewModelFactory {
    func buildViewModel(
        slippage: Decimal,
        apy: PoolApyInfo?,
        liquidityPair: LiquidityPair,
        chain: ChainModel
    ) -> LiquidityPoolSupplyViewModel
}

class LiquidityPoolSupplyViewModelFactoryDefault: LiquidityPoolSupplyViewModelFactory {
    func buildViewModel(
        slippage: Decimal,
        apy: PoolApyInfo?,
        liquidityPair: LiquidityPair,
        chain: ChainModel
    ) -> LiquidityPoolSupplyViewModel {
        let slippageString = NumberFormatter.percentPlain.stringFromDecimal(slippage)
        let slippageViewModel = TitleMultiValueViewModel(title: slippageString, subtitle: nil)

        let apyString = apy?.apy.flatMap {
            NumberFormatter.percentAPY.stringFromDecimal($0)
        }
        let apyViewModel = apyString.flatMap { TitleMultiValueViewModel(title: $0, subtitle: nil) }

        let rewardAssetSymbol = chain.assets.first(where: { $0.currencyId == liquidityPair.rewardAssetId })?.symbol.uppercased()
        let rewardTokenViewModel = TitleMultiValueViewModel(title: rewardAssetSymbol, subtitle: nil)

        return LiquidityPoolSupplyViewModel(
            slippageViewModel: slippageViewModel,
            apyViewModel: apyViewModel,
            rewardTokenViewModel: rewardTokenViewModel
        )
    }
}
