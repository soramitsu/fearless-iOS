import Foundation
import FearlessUtils

struct SubqueryPageInfo: Decodable {
    let startCursor: String?
    let endCursor: String?
}

struct SubqueryTransfer: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case fee
        case block
        case extrinsicId
        case success
    }

    let amount: String
    let receiver: String
    let sender: String
    let fee: String
    let block: String
    let extrinsicId: String?
    let success: Bool
}

struct SubqueryRewardOrSlash: Decodable {
    let amount: String
    let isReward: Bool
    let era: Int?
    let validator: String?
}

struct SubqueryExtrinsic: Decodable {
    let hash: String
    let module: String
    let call: String
    let fee: String
    let success: Bool
}

struct SubqueryErrors: Error, Decodable {
    struct SubqueryError: Error, Decodable {
        let message: String
    }

    let errors: [SubqueryError]
}

struct SubqueryHistoryElement: Decodable {
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case timestamp
        case address
        case reward
        case extrinsic
        case transfer
    }

    let identifier: String
    let timestamp: String
    let address: String
    let reward: SubqueryRewardOrSlash?
    let extrinsic: SubqueryExtrinsic?
    let transfer: SubqueryTransfer?
}

struct SubqueryHistoryResponse: Decodable {
    struct HistoryElements: Decodable {
        let pageInfo: SubqueryPageInfo
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

enum SubqueryResponse<D: Decodable>: Decodable {
    case data(_ value: D)
    case errors(_ value: SubqueryErrors)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        let json = try container.decode(JSON.self)

        if let data = json.data {
            let value = try data.map(to: D.self)
            self = .data(value)
        } else if let errors = json.errrors {
            let values = try errors.map(to: [SubqueryErrors.SubqueryError].self)
            self = .errors(SubqueryErrors(errors: values))
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "unexpected value"
            )
        }
    }
}
