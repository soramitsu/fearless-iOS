import Foundation
import FearlessUtils
import CommonWallet
import IrohaCrypto

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
    let stash: String
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
