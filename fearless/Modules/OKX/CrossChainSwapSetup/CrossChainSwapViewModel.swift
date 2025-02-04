import Foundation

struct CrossChainSwapViewModel {
    let minimumReceived: BalanceViewModelProtocol?
    let route: String?
    let sendTokenRatio: String?
    let receiveTokenRatio: String?
    let fee: String?
    let sendTokenRatioTitle: String?
    let receiveTokenRatioTitle: String?
    let liquiditySources: String?
    let slippageTitle: String?
    let routeViewModels: [ImageMarkedLabelViewModel]?
}
