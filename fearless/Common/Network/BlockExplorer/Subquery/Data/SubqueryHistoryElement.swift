import Foundation
import IrohaCrypto
import CommonWallet

struct SubqueryHistoryElement: Decodable, RewardOrSlashData {
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
    var reward: SubqueryRewardOrSlash?
    let extrinsic: SubqueryExtrinsic?
    let transfer: SubqueryTransfer?

    var rewardInfo: RewardOrSlash? {
        reward
    }
}

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var extrinsicHash: String? { nil }
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
