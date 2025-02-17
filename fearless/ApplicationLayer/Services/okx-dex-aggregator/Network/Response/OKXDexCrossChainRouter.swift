import Foundation

struct OKXDexCrossChainRouter: Decodable {
    let estimateTime: String
    let minimumReceived: String
    let toTokenAmount: String
    let fromDexRouterList: [OKXDexRouter]
    let toDexRouterList: [OKXDexRouter]
    let router: OKXCrossChainRouter
    let fromChainNetworkFee: String
}
