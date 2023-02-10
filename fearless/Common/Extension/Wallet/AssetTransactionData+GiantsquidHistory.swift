import Foundation
import CommonWallet
import BigInt
import IrohaCrypto
import FearlessUtils
import SoraFoundation

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
            BigUInt(transfer.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let type = transfer.from?.id == address ? TransactionType.outgoing :
            TransactionType.incoming

        let status: AssetTransactionStatus = transfer.success == true ? .commited : .rejected

        return AssetTransactionData(
            transactionId: transfer.id,
            status: status,
            assetId: "",
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
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
            BigUInt(reward.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? .zero

        let accountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )
        let peerId = accountId?.toHex() ?? address

        return AssetTransactionData(
            transactionId: reward.id,
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
            BigUInt(bond.amount) ?? 0,
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
            BigUInt(slash.amount) ?? 0,
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
}
