import Foundation

struct AlchemyEstimateGasRequest: Encodable {
    let to: String
    let gas: String?
    let gasPrice: String?
    let value: String?
    let data: String?
}
