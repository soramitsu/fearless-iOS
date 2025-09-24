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

        let rewardAsset = chain.assets.first(where: { $0.currencyId == liquidityPair.rewardAssetId })
        let rewardAssetSymbol = rewardAsset?.symbol.uppercased()
        let rewardTokenViewModel = TitleMultiValueViewModel(title: rewardAssetSymbol, subtitle: nil)

        let rewardTokenIconViewModel = RemoteImageViewModel(url: rewardAsset?.icon)

        return LiquidityPoolSupplyViewModel(
            slippageViewModel: slippageViewModel,
            apyViewModel: apyViewModel,
            rewardTokenViewModel: rewardTokenViewModel,
            rewardTokenIconViewModel: rewardTokenIconViewModel
        )
    }
}
