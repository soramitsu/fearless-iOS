import Foundation
import SSFUtils

import IrohaCrypto
import BigInt

struct SubqueryDelegatorHistoryItem: Decodable, RewardHistoryItemProtocol, DelegatorHistoryItem {
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case timestampInSeconds = "timestamp"
        case blockNumber
        case amount
        case delegatorId
        case collatorId
        case roundId
    }

    let id: String
    let type: SubqueryDelegationAction
    let timestampInSeconds: String
    let blockNumber: Int
    let amount: BigUInt
    let delegatorId: String?
    let collatorId: String?
    let roundId: String?

    var attribution: RewardHistoryAttribution? {
        RewardHistoryAttribution(
            validatorAddress: collatorId,
            era: roundId.flatMap { UInt64($0, radix: 10) }
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(SubqueryDelegationAction.self, forKey: .type)
        timestampInSeconds = try container.decode(String.self, forKey: .timestampInSeconds)
        blockNumber = try container.decode(Int.self, forKey: .blockNumber)
        if let amountString = try? container.decode(String.self, forKey: .amount),
           let decodedAmount = RewardAmountParser.parse(amountString) {
            amount = decodedAmount
        } else if let integerAmount = try? container.decode(UInt64.self, forKey: .amount) {
            amount = BigUInt(integerAmount)
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .amount,
                in: container,
                debugDescription: "Reward amount must be an unsigned integer"
            )
        }
        delegatorId = try? container.decode(String.self, forKey: .delegatorId)
        collatorId = try? container.decode(String.self, forKey: .collatorId)

        if let stringRoundId = try? container.decode(String.self, forKey: .roundId) {
            roundId = stringRoundId
        } else if let integerRoundId = try? container.decode(UInt64.self, forKey: .roundId) {
            roundId = String(integerRoundId)
        } else {
            roundId = nil
        }
    }
}
