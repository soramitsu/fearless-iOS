import Foundation

import BigInt
import IrohaCrypto
import SSFUtils
import SoraFoundation
import SSFModels

extension AssetTransactionData {
    static func createTransaction(
        transfer: GiantsquidTransfer,
        address: String,
        asset: AssetModel
    ) -> AssetTransactionData {
        let locale = LocalizationManager.shared.selectedLocale
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: locale).date(from: transfer.timestamp)
        let peerAddress = transfer.from?.id == address ? transfer.to?.id : transfer.from?.id
        let timestamp = Int64(date?.timeIntervalSince1970 ?? 0)
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(string: transfer.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let type = transfer.from?.id == address ? TransactionType.outgoing :
            TransactionType.incoming

        let status: AssetTransactionStatus = transfer.success == true ? .commited : .rejected

        var fees: [AssetTransactionFee] = []

        if let feeAmountString = transfer.feeAmount, let feeSubstrateAmount = BigUInt(string: feeAmountString), let feeDecimalAmount = Decimal.fromSubstrateAmount(feeSubstrateAmount, precision: Int16(asset.precision)) {
            let fee = AssetTransactionFee(
                identifier: asset.id,
                assetId: asset.id,
                amount: AmountDecimal(value: feeDecimalAmount),
                context: nil
            )

            fees.append(fee)
        }

        if let signedData = transfer.signedData, let fee = signedData.fee, let partialFee = fee.partialFee, let partialFeeDecimal = Decimal.fromSubstrateAmount(partialFee, precision: Int16(asset.precision)) {
            let fee = AssetTransactionFee(
                identifier: asset.id,
                assetId: asset.id,
                amount: AmountDecimal(value: partialFeeDecimal),
                context: nil
            )

            fees.append(fee)
        }
        var context: [String: String] = [:]
        if let blockHash = transfer.blockHash {
            context["reefBlockHash"] = blockHash
        }

        return AssetTransactionData(
            transactionId: transfer.identifier,
            status: status,
            assetId: "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: fees,
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: context
        )
    }

    static func createTransaction(
        reward: GiantsquidReward,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let locale = LocalizationManager.shared.selectedLocale
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: locale).date(from: reward.timestamp)
        let timestamp = Int64(date?.timeIntervalSince1970 ?? 0)
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(string: reward.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: reward.identifier,
            status: .commited,
            assetId: "",
            peerId: peerId,
            peerFirstName: reward.validator,
            peerLastName: nil,
            peerName: TransactionType.reward.rawValue,
            details: "#\(reward.era ?? 0)",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: timestamp,
            type: TransactionType.reward.rawValue,
            reason: reward.identifier,
            context: nil
        )
    }

    static func createTransaction(
        bond: GiantsquidBond,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let locale = LocalizationManager.shared.selectedLocale
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: locale).date(from: bond.timestamp)
        let timestamp = Int64(date?.timeIntervalSince1970 ?? 0)
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(string: bond.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: bond.id,
            status: .commited,
            assetId: "",
            peerId: peerId,
            peerFirstName: bond.accountId,
            peerLastName: nil,
            peerName: TransactionType.extrinsic.rawValue,
            details: "#\(bond.blockNumber)",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: bond.identifier,
            context: nil
        )
    }

    static func createTransaction(
        slash: GiantsquidSlash,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let locale = LocalizationManager.shared.selectedLocale
        let dateFormatter = DateFormatter.giantsquidDate
        let date = dateFormatter.value(for: locale).date(from: slash.timestamp)
        let timestamp = Int64(date?.timeIntervalSince1970 ?? 0)
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(string: slash.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: slash.id,
            status: .commited,
            assetId: "",
            peerId: peerId,
            peerFirstName: slash.accountId,
            peerLastName: nil,
            peerName: TransactionType.extrinsic.rawValue,
            details: "#\(slash.blockNumber)",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: timestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: slash.identifier,
            context: nil
        )
    }

    static func createTransaction(
        extrinsic: GiantsquidExtrinsic,
        address: String,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            (extrinsic.signedData?.fee?.partialFee).or(.zero),
            precision: Int16(asset.precision)
        ) ?? .zero

        let status: AssetTransactionStatus = extrinsic.status?.lowercased() == "success" ? .commited : .rejected

        var fees: [AssetTransactionFee] = []

        if
            let signedData = extrinsic.signedData,
            let fee = signedData.fee,
            let partialFee = fee.partialFee,
            let partialFeeDecimal = Decimal.fromSubstrateAmount(partialFee, precision: Int16(asset.precision))
        {
            let fee = AssetTransactionFee(
                identifier: asset.id,
                assetId: asset.id,
                amount: AmountDecimal(value: partialFeeDecimal),
                context: nil
            )

            fees.append(fee)
        }

        return AssetTransactionData(
            transactionId: extrinsic.hash ?? extrinsic.id,
            status: status,
            assetId: asset.id,
            peerId: address,
            peerFirstName: extrinsic.section,
            peerLastName: extrinsic.method,
            peerName: "\(extrinsic.section ?? "") \(extrinsic.method ?? "")",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: fees,
            timestamp: extrinsic.timestampInSeconds,
            type: TransactionType.extrinsic.rawValue,
            reason: extrinsic.identifier,
            context: nil
        )
    }
}
