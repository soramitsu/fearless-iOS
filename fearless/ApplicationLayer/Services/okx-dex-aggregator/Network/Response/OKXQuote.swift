import Foundation

struct OKXQuote: Decodable {
    let chainId: String
    let dexRouterList: [OKXDexRouter]
    let estimateGasFee: String
    let fromToken: OKXToken
    let fromTokenAmount: String
    let quoteCompareList: [OKXDexQuote]
    let toToken: OKXToken
    let toTokenAmount: String
}
