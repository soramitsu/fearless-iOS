import Foundation
import SSFPools
import SSFPolkaswap

struct LiquidityPoolListCellModel {
    let tokenPairIconsVieWModel: TokenPairsIconViewModel
    let tokenPairNameLabelText: String
    let rewardTokenNameLabelText: String
    let apyLabelText: String?
    let stakingStatusLabelText: String?
    let reservesLabelValue: ShimmeredLabelState?
    let sortValue: Decimal
    let liquidityPair: LiquidityPair
}
