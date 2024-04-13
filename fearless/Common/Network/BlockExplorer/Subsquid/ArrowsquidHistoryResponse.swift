import Foundation
import SSFModels

struct ArrowsquidHistoryResponse: Decodable {
    let historyElements: [ArrowsquidHistoryElement]
}

extension ArrowsquidHistoryResponse: RewardOrSlashResponse {
    var data: [RewardOrSlashData] {
        historyElements
    }
}

struct ArrowsquidHistoryElement: Decodable, RewardOrSlashData {
    var timestamp: String {
        let df = DateFormatter.giantsquidDate
        let date = Date(timeIntervalSince1970: TimeInterval(timestampValue))
        return df.value(for: Locale.current).string(from: date)
    }

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case timestampValue = "timestamp"
        case address
        case reward
        case transfer
        case extrinsicHash
        case success
    }

    let identifier: String
    let timestampValue: Int64
    let address: String
    let extrinsicHash: String?
    let success: Bool
    let reward: ArrowsquidRewardOrSlash?
    let transfer: ArrowsquidTransfer?

    var timestampInSeconds: Int64 {
        timestampValue
    }

    var rewardInfo: RewardOrSlash? {
        reward
    }
}

extension ArrowsquidHistoryElement: WalletRemoteHistoryItemProtocol {
    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        if reward != nil {
            return .rewards
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

struct ArrowsquidTransfer: Decodable {
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
    let success: Bool?
    let assetId: String?
}

struct ArrowsquidRewardOrSlash: Decodable, RewardOrSlash {
    var isReward: Bool { true }

    var era: Int?
    var validator: String?
    var eventIdx: String?

    let amount: String
    let stash: String?
    let assetId: String?
}
