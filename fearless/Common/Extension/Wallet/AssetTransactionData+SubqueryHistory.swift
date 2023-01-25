import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import FearlessUtils

extension AssetTransactionData {
    static func createTransaction(
        from item: SubqueryHistoryElement,
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
                address: address,
                chain: chain,
                asset: asset
            )
        }

        let timestamp = Int64(item.timestamp) ?? 0

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
        from item: SubqueryHistoryElement,
        transfer: SubqueryTransfer,
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

        let timestamp = Int64(item.timestamp) ?? 0

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
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    static func createTransaction(
        from item: SubscanTransferItemData,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus

        if item.finalized == false {
            status = .pending
        } else if let state = item.success {
            status = state ? .commited : .rejected
        } else {
            status = .pending
        }

        let peerAddress = item.sender == address ? item.receiver : item.sender

        let accountId = try? AddressFactory.accountId(
            from: peerAddress,
            chain: chain
        )

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)
        let feeValue = BigUInt(item.fee) ?? BigUInt(0)
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: Int16(asset.precision)) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.hash,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: amount,
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    private static func createTransaction(
        from item: SubqueryHistoryElement,
        reward: SubqueryRewardOrSlash,
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

        let timestamp = Int64(item.timestamp) ?? 0

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
            timestamp: timestamp,
            type: type,
            reason: item.identifier,
            context: nil
        )
    }

    static func createTransaction(
        from item: SubscanRewardItemData,
        address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus

        status = .commited

        let amount = Decimal.fromSubstrateAmount(
            BigUInt(item.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let type = TransactionType(rawValue: item.eventId.uppercased())

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: asset.identifier,
            peerId: item.extrinsicHash,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: address,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: type?.rawValue ?? "",
            reason: nil,
            context: nil
        )
    }

    static func createTransaction(
        from item: SubqueryHistoryElement,
        extrinsic: SubqueryExtrinsic,
        address _: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(extrinsic.fee) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let peerId = item.address

        let status: AssetTransactionStatus = extrinsic.success ? .commited : .rejected

        let timestamp = Int64(item.timestamp) ?? 0

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
            timestamp: timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: extrinsic.hash,
            context: nil
        )
    }

    static func createTransaction(
        from item: SubscanConcreteExtrinsicsItemData,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(item.fee) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )
        let peerId = accountId?.toHex() ?? address

        let status: AssetTransactionStatus

        if let state = item.success {
            status = state ? .commited : .rejected
        } else {
            status = .pending
        }

        return AssetTransactionData(
            transactionId: item.identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: item.callModule,
            peerLastName: item.callFunction,
            peerName: "\(item.callModule) \(item.callFunction)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }

    static func createTransaction(
        from item: TransactionHistoryItem,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        if item.callPath.isTransfer {
            return createLocalTransfer(
                from: item,
                address: address,
                chain: chain,
                asset: asset
            )
        } else {
            return createLocalExtrinsic(
                from: item,
                address: address,
                chain: chain,
                asset: asset
            )
        }
    }

    private static func createLocalTransfer(
        from item: TransactionHistoryItem,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let peerAddress = (item.sender == address ? item.receiver : item.sender) ?? item.sender

        let accountId = try? AddressFactory.accountId(
            from: peerAddress,
            chain: chain
        )

        let peerId = accountId?.toHex() ?? peerAddress

        let feeDecimal = Decimal.fromSubstrateAmount(
            BigUInt(item.fee) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let amount: Decimal = {
            if let encodedCall = item.call,
               let call = try? JSONDecoder.scaleCompatible()
               .decode(RuntimeCall<TransferCall>.self, from: encodedCall) {
                return Decimal.fromSubstrateAmount(call.args.value, precision: Int16(asset.precision)) ?? .zero
            } else {
                return .zero
            }
        }()

        let type = item.sender == address ? TransactionType.outgoing :
            TransactionType.incoming

        return AssetTransactionData(
            transactionId: item.txHash,
            status: item.status.walletValue,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    private static func createLocalExtrinsic(
        from item: TransactionHistoryItem,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(item.fee) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let accountId = try? AddressFactory.accountId(
            from: item.sender,
            chain: chain
        )

        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: item.identifier,
            status: item.status.walletValue,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: item.callPath.moduleName,
            peerLastName: item.callPath.callName,
            peerName: "\(item.callPath.moduleName) \(item.callPath.callName)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: item.timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }
}
