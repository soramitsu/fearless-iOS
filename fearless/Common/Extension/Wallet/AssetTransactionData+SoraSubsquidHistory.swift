import Foundation
import CommonWallet
import SoraFoundation
import SSFModels
import BigInt

extension AssetTransactionData {
    static func createTransaction(
        from item: SoraSubsquidHistoryElement,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let assetId = item.data?.anyAssetId ?? ""
        let feePlanckString = item.networkFee ?? ""
        let feePlanck = BigUInt(string: feePlanckString) ?? .zero
        let fee = Decimal.fromSubstrateAmount(feePlanck, precision: Int16(asset.precision)) ?? .zero

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
                address: address,
                chain: chain,
                asset: asset,
                fee: transactionFee
            )
        case ("assets", "transfer"):
            return createTransferTransaction(
                from: item,
                address: address,
                chain: chain,
                asset: asset,
                fee: transactionFee
            )
        case (.some(_), "swap"):
            return createSwapTransaction(
                from: item,
                address: address,
                chain: chain,
                asset: asset,
                fee: transactionFee
            )
        case (.some(_), "transferToSidechain"):
            return createBridgeTransaction(
                from: item,
                address: address,
                chain: chain,
                asset: asset,
                fee: transactionFee
            )
        default:
            return createExtrinsicTransaction(
                from: item,
                address: address,
                chain: chain,
                asset: asset,
                fee: transactionFee
            )
        }
    }

    static func createTransferTransaction(
        from item: SoraSubsquidHistoryElement,
        address: String,
        chain _: ChainModel,
        asset _: AssetModel,
        fee: AssetTransactionFee
    ) -> AssetTransactionData {
        let from = item.data?.from
        let to = item.data?.to
        let assetId = item.data?.assetId ?? ""
        let amount = item.data?.amount ?? ""
        let type = from == address ? TransactionType.outgoing :
            TransactionType.incoming
        let timestamp = item.itemTimestamp

        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: assetId,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: to,
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
        address _: String,
        chain _: ChainModel,
        asset _: AssetModel,
        fee: AssetTransactionFee
    ) -> AssetTransactionData {
        let type = TransactionType.reward
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

    static func createSwapTransaction(
        from item: SoraSubsquidHistoryElement,
        address _: String,
        chain _: ChainModel,
        asset _: AssetModel,
        fee: AssetTransactionFee
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
        address _: String,
        chain _: ChainModel,
        asset _: AssetModel,
        fee: AssetTransactionFee
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
        address _: String,
        chain _: ChainModel,
        asset _: AssetModel,
        fee: AssetTransactionFee
    ) -> AssetTransactionData {
        let from = item.data?.from
        let to = item.data?.to
        let assetId = item.data?.assetId ?? ""
        let amount = item.data?.amount ?? ""
        let timestamp = item.itemTimestamp

        return AssetTransactionData(
            transactionId: item.id,
            status: .commited,
            assetId: assetId,
            peerId: "",
            peerFirstName: item.module,
            peerLastName: item.method,
            peerName: to,
            details: "",
            amount: AmountDecimal(string: amount) ?? AmountDecimal(value: 0),
            fees: [fee],
            timestamp: timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: "",
            context: nil
        )
    }
}
