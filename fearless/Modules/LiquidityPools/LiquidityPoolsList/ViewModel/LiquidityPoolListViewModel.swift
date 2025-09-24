import Foundation

struct LiquidityPoolListViewModel {
    let poolViewModels: [LiquidityPoolListCellModel]?
    let titleLabelText: String
    let moreButtonVisible: Bool
    let backgroundVisible: Bool
    let refreshAvailable: Bool
    let isEmbed: Bool
}
