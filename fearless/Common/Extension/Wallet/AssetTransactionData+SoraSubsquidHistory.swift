import Foundation
import CommonWallet
import SoraFoundation
import SSFModels
import BigInt

extension AssetTransactionData {
    static func createTransaction(
        from item: SoraSubsquidHistoryElement,
        address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let assetId = item.data?.anyAssetId ?? ""
        let feePlanckString = item.networkFee ?? ""
        let feePlanck = BigUInt(string: feePlanckString) ?? .zero
        let fee = Decimal.fromSubstrateAmount(feePlanck, precision: Int16(asset.precision)) ?? .zero

        let success = item.execution?.success == true
        let status: AssetTransactionStatus = success ? .commited : .rejected

        let transactionFee = AssetTransactionFee(
            identifier: item.id,
            assetId: assetId,
            amount: AmountDecimal(value: fee),
            context: nil
        )

        switch (item.module, item.method) {
        case ("staking", "rewarded"):
            return createRewardTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        case ("assets", "transfer"):
            return createTransferTransaction(
                from: item,
                address: address,
                fee: transactionFee,
                status: status
            )
        case (.some(_), "swap"):
            return createSwapTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        case (.some(_), "transferToSidechain"):
            return createBridgeTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        default:
            return createExtrinsicTransaction(
                from: item,
                fee: transactionFee,
                status: status
            )
        }
    }

    static func createTransferTransaction(
        from item: SoraSubsquidHistoryElement,
        address: String,
        fee: AssetTransactionFee,
        status: AssetTransactionStatus
    ) -> AssetTransactionData {
        let from = item.data?.from
        let to = item.data?.to
        let assetId = item.data?.assetId ?? ""
        let amount = item.data?.amount ?? ""
        let type = from == address ? TransactionType.outgoing :
            TransactionType.incoming
        let timestamp = item.itemTimestamp
        let peer = from == address ? to : from

        return AssetTransactionData(
            transactionId: item.id,
            status: status,
            assetId: assetId,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peer,
            details: "",
            amount: AmountDecimal(string: amount) ?? AmountDecimal(value: 0),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    static func createRewardTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status: AssetTransactionStatus
    ) -> AssetTransactionData {
        let type = TransactionType.reward
        let timestamp = item.itemTimestamp
        let stash = item.data?.stash
        let amount = item.data?.amount ?? ""
        let era = item.data?.era.map { "\($0)" } ?? ""

        return AssetTransactionData(
            transactionId: item.id,
            status: status,
            assetId: "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: stash,
            details: era,
            amount: AmountDecimal(string: amount) ?? AmountDecimal(value: 0),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    static func createSwapTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status _: AssetTransactionStatus
    ) -> AssetTransactionData {
        let type = TransactionType.swap
        let timestamp = item.itemTimestamp
        let stash = item.data?.stash
        let amount = item.data?.targetAssetAmount ?? ""
        let assetId = item.data?.targetAssetId ?? ""
        let baseAssetId = item.data?.baseAssetId ?? ""
        let sendAmount = item.data?.baseAssetAmount ?? ""
        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: assetId,
            peerId: baseAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: stash,
            details: sendAmount,
            amount: AmountDecimal(string: amount) ?? AmountDecimal(value: 0),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    static func createBridgeTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status _: AssetTransactionStatus
    ) -> AssetTransactionData {
        let type = TransactionType.bridge
        let timestamp = item.itemTimestamp
        let stash = item.data?.stash
        let amount = item.data?.amount ?? ""
        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: stash,
            details: "",
            amount: AmountDecimal(string: amount) ?? AmountDecimal(value: 0),
            fees: [fee],
            timestamp: timestamp,
            type: type.rawValue,
            reason: "",
            context: nil
        )
    }

    static func createExtrinsicTransaction(
        from item: SoraSubsquidHistoryElement,
        fee: AssetTransactionFee,
        status _: AssetTransactionStatus
    ) -> AssetTransactionData {
        let from = item.address ?? ""
        let to = item.data?.to
        let assetId = item.data?.assetId ?? ""
        let amount = item.data?.amount ?? ""
        let timestamp = item.itemTimestamp

        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: assetId,
            peerId: from,
            peerFirstName: item.module,
            peerLastName: item.method,
            peerName: to,
            details: "",
            amount: fee.amount,
            fees: [fee],
            timestamp: timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: "",
            context: nil
        )
    }
}
