import Foundation
import BigInt

import IrohaCrypto
import SSFModels

struct GiantsquidReward: Decodable {
    enum CodingKeys: String, CodingKey {
        case amount
        case era
        case accountId
        case validator
        case timestamp
        case extrinsicHash
        case blockNumber
        case id
    }

    let amount: String
    let era: Int?
    let accountId: String?
    let validator: String?
    let timestamp: String
    let extrinsicHash: String?
    let blockNumber: UInt32?
    let id: String?

    var timestampInSeconds: Int64 {
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: Locale.current).date(from: timestamp)
        return Int64(date?.timeIntervalSince1970 ?? 0)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        amount = try container.decode(String.self, forKey: .amount)
        era = try container.decodeIfPresent(Int.self, forKey: .era)
        accountId = try container.decodeIfPresent(String.self, forKey: .accountId)
        validator = try container.decodeIfPresent(String.self, forKey: .validator)
        extrinsicHash = try container.decodeIfPresent(String.self, forKey: .extrinsicHash)
        blockNumber = try container.decodeIfPresent(UInt32.self, forKey: .blockNumber)
        id = try container.decodeIfPresent(String.self, forKey: .id)

        do {
            timestamp = try container.decode(String.self, forKey: .timestamp)
        } catch {
            let timestampValue = try container.decode(UInt64.self, forKey: .timestamp)
            timestamp = "\(timestampValue)"
        }
    }
}

extension GiantsquidReward: RewardOrSlashData, RewardOrSlash {
    var address: String {
        accountId ?? ""
    }

    var rewardInfo: RewardOrSlash? {
        self
    }

    var isReward: Bool {
        true
    }

    var stash: String? {
        accountId
    }

    var eventIdx: String? {
        id
    }

    var assetId: String? {
        nil
    }
}

extension GiantsquidReward: WalletRemoteHistoryItemProtocol {
    var identifier: String {
        id.or(extrinsicHash.or(timestamp + amount))
    }

    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var itemTimestamp: Int64 { timestampInSeconds }
    var label: WalletRemoteHistorySourceLabel {
        .rewards
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData.createTransaction(
            reward: self,
            address: address,
            chain: chain,
            asset: asset
        )
    }
}
