import Foundation

struct OKXCrossChainSwapTransaction: Decodable {
    let data: String
    let from: String
    let gasLimit: String
    let gasPrice: String
    let maxPriorityFeePerGas: String
    let to: String
    let value: String
}
