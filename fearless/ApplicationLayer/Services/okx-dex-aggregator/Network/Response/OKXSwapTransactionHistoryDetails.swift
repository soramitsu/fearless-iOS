struct OKXSwapTransactionHistoryDetails: Decodable {
    let chainId: String
    let txHash: String?
    let txTime: String?
    let status: String?
    let txType: String?
    let fromAddress: String?
    let dexRouter: String?
    let toAddress: String?
    let fromTokenDetails: OKXDexToken?
    let toTokenDetails: OKXDexToken?
    let referalAmount: String?
    let errorMsg: String?
    let gasLimit: String?
    let gasUsed: String?
    let gasPrice: String?
    let txFee: String?
    
    var transactionFinished: Bool {
        let status = OKXCrossChainTxDetailStatus(txDetailStatus: status)

        switch status {
        case .success, .fromFailure:
            return true
        default:
            return false
        }
    }
    
    var swapDetailStatus: OKXCrossChainTxDetailStatus {
        let crossChainStatus = OKXCrossChainTxDetailStatus(txDetailStatus: status)

        switch crossChainStatus {
        case .waiting:
            return .waiting
        case .fromSuccess:
            return .success
        case .fromFailure:
            return .fromFailure
        case .bridgePending:
            return .bridgePending
        case .bridgeSuccess:
            return .bridgeSuccess
        case .success:
            return .success
        case .refund:
            return .refund
        case .notFound:
            return .notFound
        }
    }
}
