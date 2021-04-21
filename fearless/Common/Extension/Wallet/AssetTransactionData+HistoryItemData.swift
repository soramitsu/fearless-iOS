import Foundation
import CommonWallet
import BigInt
import IrohaCrypto

extension AssetTransactionData {
    static func createTransaction(
        from item: SubscanTransferItemData,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
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

        let accountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        let peerId = accountId?.toHex() ?? peerAddress

        let amount = AmountDecimal(string: item.amount) ?? AmountDecimal(value: 0)
        let feeValue = BigUInt(item.fee) ?? BigUInt(0)
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero

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

    static func createTransaction(
        from item: SubscanRewardItemData,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory _: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus

        status = .commited

        let amount: Decimal = {
            guard let amountValue = BigUInt(item.amount) else {
                return 0.0
            }

            return Decimal.fromSubstrateAmount(amountValue, precision: networkType.precision) ?? 0.0
        }()

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
        from item: SubscanConcreteExtrinsicsItemData,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let amount: Decimal = {
            guard let amountValue = BigUInt(item.fee) else {
                return 0.0
            }

            return Decimal.fromSubstrateAmount(amountValue, precision: networkType.precision) ?? 0.0
        }()

        let accountId = try? addressFactory.accountId(
            fromAddress: address,
            type: networkType
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
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let peerAddress = item.sender == address ? item.receiver : item.sender

        let accountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        let peerId = accountId?.toHex() ?? peerAddress
        let feeDecimal: Decimal = {
            guard let feeValue = BigUInt(item.fee) else {
                return .zero
            }

            return Decimal.fromSubstrateAmount(feeValue, precision: networkType.precision) ?? .zero
        }()

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

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
            amount: <#T##AmountDecimal#>
            fees: [fee],
            timestamp: item.timestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }
}
