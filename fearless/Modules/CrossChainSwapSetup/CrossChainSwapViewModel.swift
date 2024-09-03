import Foundation

struct CrossChainSwapViewModel {
    let minimumReceived: BalanceViewModelProtocol?
    let route: String?
    let sendTokenRatio: String?
    let receiveTokenRatio: String?
    let fee: BalanceViewModelProtocol?
    let sendTokenRatioTitle: String?
    let receiveTokenRatioTitle: String?
}
