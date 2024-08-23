import Foundation

struct OKXSwap: Decodable {
    let routerResult: OKXQuote
    let tx: OKXSwapTransaction
}
