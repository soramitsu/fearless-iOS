import Foundation

import BigInt
import IrohaCrypto
import SSFUtils
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        from item: ArrowsquidHistoryElement,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        if let transfer = item.transfer {
            return createTransaction(
                from: item,
                transfer: transfer,
                address: address,
                chain: chain,
                asset: asset
            )
        }

        if let reward = item.reward {
            return createTransaction(
                from: item,
                reward: reward,
                address: address,
                chain: chain,
                asset: asset
            )
        }

        let timestamp = item.timestampInSeconds

        return AssetTransactionData(
            transactionId: item.identifier,
            status: .pending,
            assetId: asset.identifier,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: "",
            details: "",
            amount: AmountDecimal(value: 0),
            fees: [],
            timestamp: timestamp,
            type: "UNKNOWN",
            reason: nil,
            context: nil
        )
    }

    private static func createTransaction(
        from item: ArrowsquidHistoryElement,
        transfer: ArrowsquidTransfer,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = item.success ? .commited : .rejected

        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender

        let accountId = try? AddressFactory.accountId(
            from: peerAddress,
            chain: chain
        )

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = Decimal.fromSubstrateAmount(
            BigUInt(string: transfer.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero
        let feeValue = BigUInt(string: transfer.fee ?? "") ?? BigUInt(0)
        let utilityAsset = chain.utilityChainAssets().first?.asset ?? asset
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: Int16(utilityAsset.precision)) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = transfer.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.extrinsicHash ?? item.identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestampInSeconds,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    private static func createTransaction(
        from item: ArrowsquidHistoryElement,
        reward: ArrowsquidRewardOrSlash,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = .commited

        let amount = Decimal.fromSubstrateAmount(
            BigUInt(string: reward.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let type = reward.isReward ? TransactionType.reward.rawValue : TransactionType.slash.rawValue

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: reward.validator,
            peerLastName: nil,
            peerName: type,
            details: "#\(reward.era ?? 0)",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestampInSeconds,
            type: type,
            reason: item.identifier,
            context: nil
        )
    }
}
