import Foundation

struct OKXAvailableDestination: Decodable {
    let fromChainId: String
    let toChainId: String
    let fromTokenAddress: String
    let toTokenAddress: String
    let fromTokenSymbol: String
    let toTokenSymbol: String
}
