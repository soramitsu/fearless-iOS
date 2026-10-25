import Foundation

struct OKXSwapTransaction: Decodable {
    let data: String
    let estimateErrorMsg: String
    let from: String
    let gas: String
    let gasPrice: String
    let isEstimateError: Bool
    let maxPriorityFeePerGas: String
    let minReceiveAmount: String
    let to: String
    let value: String
}
