import Foundation

struct CrossChainTxTrackingViewModel {
    let statusViewModels: [Any]
    let statusTitle: String?
    let statusDescription: String?
    let walletName: String?
    let date: String?
    let amount: BalanceViewModelProtocol?
    let fromChainTxHash: String?
    let toChainTxHash: String?
    let fromChainFee: BalanceViewModelProtocol?
    let toChainFee: BalanceViewModelProtocol?
    let detailStatus: String?
    let fromHashViewTitle: String?
    let toHashViewTitle: String?
    let fromFeeViewTitle: String?
    let toFeeViewTitle: String?
}
