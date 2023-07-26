import Foundation

struct EtherscanHistoryResponse: Decodable {
    let status: String
    let message: String
    let result: [EtherscanHistoryElement]
}
