import Foundation
import FearlessUtils
import CommonWallet
import IrohaCrypto
import BigInt

struct SubqueryPageInfo: Decodable {
    let startCursor: String?
    let endCursor: String?

    func toContext() -> [String: String]? {
        if startCursor == nil, endCursor == nil {
            return nil
        }
        var context: [String: String] = [:]
        if let startCursor = startCursor {
            context["startCursor"] = startCursor
        }

        if let endCursor = endCursor {
            context["endCursor"] = endCursor
        }

        return context
    }
}

struct SubqueryTransfer: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case fee
        case block
        case extrinsicId
        case extrinsicHash
        case success
    }

    let amount: String
    let receiver: String
    let sender: String
    let fee: String
    let block: String?
    let extrinsicId: String?
    let extrinsicHash: String?
    let success: Bool
}

struct SubqueryRewardOrSlash: Decodable {
    let amount: String
    let isReward: Bool
    let era: Int?
    let validator: String?
    let stash: String?
    let eventIdx: Int?
}

struct SubqueryExtrinsic: Decodable {
    let hash: String
    let module: String
    let call: String
    let fee: String
    let success: Bool
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

struct SubqueryCollatorDataResponse: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryCollatorData]
    }

    let collatorRounds: HistoryElements
}

struct SubqueryCollatorData: Decodable, Equatable {
    let collatorId: String
    let apr: Double
}

struct SubqueryHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let pageInfo: SubqueryPageInfo
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

struct SubqueryRewardOrSlashData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryHistoryElement]
    }

    let historyElements: HistoryElements
}

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { Int64(timestamp) ?? 0 }
    var label: WalletRemoteHistorySourceLabel {
        if reward != nil {
            return .rewards
        }

        if extrinsic != nil {
            return .extrinsics
        }

        return .transfers
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            chain: chain,
            asset: asset,
            addressFactory: addressFactory
        )
    }
}

struct SubqueryDelegatorHistoryData: Decodable {
    struct HistoryElements: Decodable {
        let nodes: [SubqueryDelegatorHistoryElement]
    }

    let delegators: HistoryElements
}

struct SubqueryDelegatorHistoryElement: Decodable {
    let id: String?
    let delegatorHistoryElements: SubqueryDelegatorHistoryNodes
}

struct SubqueryDelegatorHistoryNodes: Decodable {
    let nodes: [SubqueryDelegatorHistoryItem]
}

struct SubqueryDelegatorHistoryItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case type
        case timestamp
        case blockNumber
    }

    let id: String
    @StringCodable var amount: BigUInt
    let type: SubqueryDelegationAction
    let timestamp: String
    let blockNumber: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(SubqueryDelegationAction.self, forKey: .type)
        timestamp = try container.decode(String.self, forKey: .timestamp)
        blockNumber = try container.decode(Int.self, forKey: .blockNumber)

        let amountValue = try? container.decode(Decimal.self, forKey: .amount)
        let amountString = amountValue?.toString(locale: nil, digits: 0)
        amount = BigUInt(stringLiteral: amountString ?? "0")
    }
}
