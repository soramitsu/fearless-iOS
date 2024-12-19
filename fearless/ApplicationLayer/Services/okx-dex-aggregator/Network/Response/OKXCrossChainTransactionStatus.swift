import Foundation

struct OKXCrossChainTransactionStatus: Decodable {
    let bridgeHash: String
    let fromChainId: String
    let toChainId: String
    let fromAmount: String
    let toAmount: String
    let errorMsg: String?
    let toTxHash: String?
    let fromTxHash: String
    let refundTokenAddress: String?
    let detailStatus: String
    let status: String
    let toTokenAddress: String
    let fromTokenAddress: String
    let sourceChainGasfee: String
    let destinationChainGasfee: String

    var transactionFinished: Bool {
        let status = OKXCrossChainTxDetailStatus(rawValue: detailStatus)

        switch status {
        case .success, .fromFailure:
            return true
        default:
            return false
        }
    }

    var transactionFailed: Bool {
        detailStatus.lowercased() == OKXCrossChainTxDetailStatus.fromFailure.rawValue.lowercased()
    }

    var swapDetailStatus: OKXCrossChainTxDetailStatus {
        let crossChainStatus = OKXCrossChainTxDetailStatus(rawValue: detailStatus)

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
        case .none:
            return .fromFailure
        case .notFound:
            return .notFound
        }
    }
}
