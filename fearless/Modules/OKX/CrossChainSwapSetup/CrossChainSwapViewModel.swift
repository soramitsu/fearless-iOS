import Foundation

struct CrossChainSwapViewModel {
    let minimumReceived: BalanceViewModelProtocol?
    let route: TitleMultiValueViewModel?
    let sendTokenRatio: String?
    let receiveTokenRatio: String?
    let fee: String?
    let sendTokenRatioTitle: String?
    let receiveTokenRatioTitle: String?
    let liquiditySources: String?
    let slippageTitle: TitleMultiValueViewModel?
    let routeViewModels: [ImageMarkedLabelViewModel]?
    let txTime: String?
    let walletFee: BalanceViewModelProtocol?
}
