import Foundation
import CommonWallet
import SSFModels

struct SubsquidHistoryResponse: Decodable {
    let historyElements: [SubsquidHistoryElement]
}

extension SubsquidHistoryResponse: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        historyElements
    }
}

struct SubsquidHistoryElement: Decodable, RewardOrSlashData {
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
    let reward: SubsquidRewardOrSlash?
    let extrinsic: SubsquidExtrinsic?
    let transfer: SubsquidTransfer?

    var timestampInSeconds: Int64 {
        (Int64(timestamp) ?? 0) / 1000
    }

    var rewardInfo: RewardOrSlash? {
        reward
    }
}

struct SubsquidTransfer: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case receiver = "to"
        case sender = "from"
        case fee
        case block
        case extrinsicId
        case extrinsicHash
        case success
        case assetId
    }

    let amount: String
    let receiver: String
    let sender: String
    let fee: String?
    let block: String?
    let extrinsicId: String?
    let extrinsicHash: String?
    let success: Bool
    let assetId: String?
}

struct SubsquidRewardOrSlash: Decodable, RewardOrSlash {
    let amount: String
    let isReward: Bool
    let era: Int?
    let validator: String?
    let stash: String?
    let eventIdx: String?
    let assetId: String?
}

struct SubsquidExtrinsic: Decodable {
    let hash: String
    let module: String
    let call: String
    let fee: String
    let success: Bool
    let assetId: String?
}

extension SubsquidHistoryElement: WalletRemoteHistoryItemProtocol {
    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
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
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            from: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
