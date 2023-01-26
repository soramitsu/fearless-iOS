import Foundation
import FearlessUtils
import CommonWallet
import IrohaCrypto
import BigInt

struct SubqueryDelegatorHistoryItem: Decodable {
    let id: String
    let type: SubqueryDelegationAction
    let timestamp: String
    let blockNumber: Int
    let amount: BigUInt

    init(json: [String: Any]) throws {
        if let amount = json["amount"] as? UInt64 {
            self.amount = BigUInt(integerLiteral: amount)
        } else if let amount = json["amount"] as? Decimal {
            let amountString = amount.toString(locale: nil, digits: 0)
            self.amount = BigUInt(stringLiteral: amountString ?? "0")
        } else {
            throw SubqueryHistoryOperationFactoryError.incorrectInputData
        }

        guard let id = json["id"] as? String,
              let type = json["type"] as? Int,
              let timestamp = json["timestamp"] as? String,
              let blockNumber = json["blockNumber"] as? Int
        else {
            throw SubqueryHistoryOperationFactoryError.incorrectInputData
        }

        self.id = id
        self.type = SubqueryDelegationAction(rawValue: type) ?? .unknown
        self.timestamp = timestamp
        self.blockNumber = blockNumber
    }
}
