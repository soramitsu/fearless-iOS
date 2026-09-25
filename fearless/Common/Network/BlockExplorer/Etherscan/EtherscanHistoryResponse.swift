import Foundation

enum EtherscanHistoryError: Error, Equatable {
    case invalidEndpoint
    case missingAPIKey
    case providerRejected
    case invalidHTTPResponse
}

struct EtherscanHistoryResponse: Decodable {
    let result: [EtherscanHistoryElement]

    private enum CodingKeys: String, CodingKey {
        case status
        case message
        case result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(String.self, forKey: .status)
        let message = try container.decode(String.self, forKey: .message)
        let transactions = try? container.decode([EtherscanHistoryElement].self, forKey: .result)

        if status == "1", message == "OK", let transactions {
            result = transactions
        } else if status == "0", message == "No transactions found",
                  transactions?.isEmpty == true ||
                  (try? container.decode(String.self, forKey: .result)) == "No transactions found" {
            result = []
        } else {
            // V2 also uses status 0 for invalid keys, unsupported chains and rate limits.
            // Never turn those provider failures into a successful empty history page.
            throw EtherscanHistoryError.providerRejected
        }
    }
}
