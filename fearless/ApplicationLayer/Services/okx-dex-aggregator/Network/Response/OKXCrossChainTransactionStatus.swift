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
}
