import Foundation
import BigInt
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        event: TonAccountEvent,
        action: AccountEventAction,
        address: String,
        chain _: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData? {
        let status: AssetTransactionStatus = event.isInProgress ? .pending : .commited

        var fees: [AssetTransactionFee] = []
        if let feeValue = BigUInt(string: String(abs(event.fee))),
           let feeValue = Decimal.fromSubstrateAmount(feeValue, precision: Int16(asset.precision)) {
            let fee = AssetTransactionFee(
                identifier: asset.id,
                assetId: asset.id,
                amount: AmountDecimal(value: feeValue),
                context: nil
            )
            fees.append(fee)
        }

        switch action.type {
        case let .tonTransfer(tonTransfer):
            let amountString = String(tonTransfer.amount)
            guard
                let amountValue = BigUInt(string: amountString),
                let amount = Decimal.fromSubstrateAmount(amountValue, precision: Int16(asset.precision))
            else {
                return nil
            }

            let friendlyAddress = tonTransfer.sender.address.toFriendly().toString()
            let type: TransactionType = friendlyAddress == address ? .outgoing : .incoming
            let peerAddress = type == .incoming ? friendlyAddress : address

            var iconContext: [String: String] = [:]
            if let iconUrl = asset.icon?.absoluteString {
                iconContext["icon"] = iconUrl
            }
            return AssetTransactionData(
                transactionId: event.eventId,
                status: status,
                assetId: "",
                peerId: "",
                peerFirstName: nil,
                peerLastName: nil,
                peerName: peerAddress,
                details: "",
                amount: AmountDecimal(value: amount),
                fees: fees,
                timestamp: Int64(event.timestamp),
                type: type.rawValue,
                reason: "",
                context: iconContext
            )
        case let .contractDeploy(deploy):
            return AssetTransactionData(
                transactionId: event.eventId,
                status: .commited,
                assetId: "",
                peerId: "",
                peerFirstName: action.preview.name,
                peerLastName: action.preview.description,
                peerName: deploy.address.toFriendly().toString(),
                details: "",
                amount: AmountDecimal(value: .zero),
                fees: fees,
                timestamp: Int64(event.timestamp),
                type: TransactionType.extrinsic.rawValue,
                reason: "",
                context: nil
            )
        case let .jettonTransfer(jettonTransfer):
            let amountString = String(jettonTransfer.amount)
            guard
                let amountValue = BigUInt(string: amountString),
                let amount = Decimal.fromSubstrateAmount(amountValue, precision: Int16(asset.precision))
            else {
                return nil
            }

            let sender = jettonTransfer.sender?.address.toFriendly().toString()
            let type: TransactionType = sender == address ? .outgoing : .incoming

            var iconContext: [String: String] = [:]
            if let iconUrl = jettonTransfer.jettonInfo.imageURL?.absoluteString {
                iconContext["icon"] = iconUrl
            }
            return AssetTransactionData(
                transactionId: event.eventId,
                status: status,
                assetId: "",
                peerId: "",
                peerFirstName: nil,
                peerLastName: nil,
                peerName: jettonTransfer.recipientAddress.toFriendly().toString(),
                details: "",
                amount: AmountDecimal(value: amount),
                fees: fees,
                timestamp: Int64(event.timestamp),
                type: type.rawValue,
                reason: "",
                context: iconContext
            )
        case let .jettonSwap(swap):

            let amountDecimal = Decimal.fromSubstrateAmount(
                swap.amountIn,
                precision: Int16(asset.precision)
            ) ?? .zero
            let amount = AmountDecimal(value: amountDecimal)
            return AssetTransactionData(
                transactionId: event.eventId,
                status: status,
                assetId: swap.jettonInfoIn?.symbol ?? "",
                peerId: swap.jettonInfoOut?.symbol ?? "",
                peerFirstName: nil,
                peerLastName: nil,
                peerName: "",
                details: String(swap.amountOut),
                amount: amount,
                fees: fees,
                timestamp: .zero,
                type: TransactionType.swap.rawValue,
                reason: "",
                context: nil
            )
        default:
            return nil
        }
    }
}
