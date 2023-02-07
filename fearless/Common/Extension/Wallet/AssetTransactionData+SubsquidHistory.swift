import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import FearlessUtils

extension AssetTransactionData {
    static func createTransaction(
        from item: SubsquidHistoryElement,
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

        if let extrinsic = item.extrinsic {
            return createTransaction(
                from: item,
                extrinsic: extrinsic,
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
        from item: SubsquidHistoryElement,
        transfer: SubsquidTransfer,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = transfer.success ? .commited : .rejected

        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender

        let accountId = try? AddressFactory.accountId(
            from: peerAddress,
            chain: chain
        )

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = Decimal.fromSubstrateAmount(
            BigUInt(transfer.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero
        let feeValue = BigUInt(transfer.fee) ?? BigUInt(0)
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: Int16(asset.precision)) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = transfer.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.identifier,
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
        from item: SubsquidHistoryElement,
        reward: SubsquidRewardOrSlash,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = .commited

        let amount = Decimal.fromSubstrateAmount(
            BigUInt(reward.amount) ?? 0,
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

    static func createTransaction(
        from item: SubsquidHistoryElement,
        extrinsic: SubsquidExtrinsic,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(extrinsic.fee) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let peerId = item.address

        let status: AssetTransactionStatus = extrinsic.success ? .commited : .rejected

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: extrinsic.module,
            peerLastName: extrinsic.call,
            peerName: "\(extrinsic.module) \(extrinsic.call)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestampInSeconds,
            type: TransactionType.extrinsic.rawValue,
            reason: extrinsic.hash,
            context: nil
        )
    }
}
