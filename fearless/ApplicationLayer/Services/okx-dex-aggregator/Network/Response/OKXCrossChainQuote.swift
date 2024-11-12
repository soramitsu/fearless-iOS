import Foundation

struct OKXCrossChainQuote: Decodable {
    let fromChainId: String
    let fromTokenAmount: String
    let toChainId: String
    let fromToken: OKXToken
    let toToken: OKXToken
    let routerList: [OKXDexCrossChainRouter]
}
