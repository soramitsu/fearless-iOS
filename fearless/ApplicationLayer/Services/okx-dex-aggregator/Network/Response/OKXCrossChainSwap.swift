import Foundation

struct OKXCrossChainSwap: Decodable {
    let fromTokenAmount: String?
    let router: OKXCrossChainRouter
    let toTokenAmount: String?
    let minimumReceive: String?
    let tx: OKXCrossChainSwapTransaction
}
