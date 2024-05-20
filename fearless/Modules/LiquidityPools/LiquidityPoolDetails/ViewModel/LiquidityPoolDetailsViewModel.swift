import Foundation

struct LiquidityPoolDetailsViewModel {
    let pairTitleLabelText: String
    let baseAssetName: String
    let targetAssetName: String
    let reservesViewModel: TitleMultiValueViewModel?
    let apyViewModel: TitleMultiValueViewModel?
    let rewardTokenLabelText: String
    let baseAssetViewModel: BalanceViewModelProtocol?
    let targetAssetViewModel: BalanceViewModelProtocol?
    let tokenPairIconsViewModel: PolkaswapDoubleSymbolViewModel?
    let userPoolFieldsHidden: Bool
}
