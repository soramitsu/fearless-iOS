import Foundation
import IrohaCrypto
import CommonWallet
import BigInt

extension SubqueryHistoryElement: WalletRemoteHistoryItemProtocol {
    var itemBlockNumber: UInt64 {
        0
    }

    var itemExtrinsicIndex: UInt16 {
        0
    }

    var itemTimestamp: Int64 {
        Int64(timestamp) ?? 0
    }

    var label: WalletRemoteHistorySourceLabel {
        if reward != nil {
            return .rewards
        }

        if transfer != nil {
            return .transfers
        }

        return .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        if let rewardOrSlash = reward {
            return createTransactionForRewardOrSlash(
                rewardOrSlash,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        if let transfer = transfer {
            return createTransactionForTransfer(
                transfer,
                address: address,
                networkType: networkType,
                asset: asset,
                addressFactory: addressFactory
            )
        }

        return createTransactionForExtrinsic(
            extrinsic!,
            address: address,
            networkType: networkType,
            asset: asset,
            addressFactory: addressFactory
        )
    }

    private func createTransactionForExtrinsic(
        _ extrinsic: SubqueryExtrinsic,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let amount: Decimal = {
            guard let amountValue = BigUInt(extrinsic.fee) else {
                return 0.0
            }

            return Decimal.fromSubstrateAmount(amountValue, precision: asset.precision) ?? 0.0
        }()

        let accountId = try? addressFactory.accountId(
            fromAddress: address,
            type: networkType
        )

        let peerId = accountId?.toHex() ?? address

        let status: AssetTransactionStatus = extrinsic.success ? .commited : .rejected

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerId,
            peerFirstName: extrinsic.module,
            peerLastName: extrinsic.call,
            peerName: "\(extrinsic.module) \(extrinsic.call)",
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: itemTimestamp,
            type: TransactionType.extrinsic.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForTransfer(
        _ transfer: SubqueryTransfer,
        address: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let status = transfer.success ? AssetTransactionStatus.commited : AssetTransactionStatus.rejected

        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender

        let peerAccountId = try? addressFactory.accountId(
            fromAddress: peerAddress,
            type: networkType
        )

        let amountValue = BigUInt(transfer.amount) ?? 0
        let amountDecimal = Decimal.fromSubstrateAmount(amountValue, precision: asset.precision) ?? .zero

        let feeValue = BigUInt(transfer.fee) ?? 0
        let feeDecimal = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = transfer.sender == address ? TransactionType.outgoing : TransactionType.incoming

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: asset.identifier,
            peerId: peerAccountId?.toHex() ?? "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: peerAddress,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: type.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForRewardOrSlash(
        _ rewardOrSlash: SubqueryRewardOrSlash,
        address _: String,
        networkType: SNAddressType,
        asset: WalletAsset,
        addressFactory: SS58AddressFactoryProtocol
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(rewardOrSlash.amount) ?? 0,
            precision: asset.precision
        )

        let type = rewardOrSlash.isReward ? TransactionType.reward.rawValue : TransactionType.slash.rawValue

        let validatorAddress = rewardOrSlash.validator ?? ""

        let validatorAccountId = try? addressFactory.accountId(
            fromAddress: validatorAddress,
            type: networkType
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: .commited,
            assetId: asset.identifier,
            peerId: validatorAccountId?.toHex() ?? "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: validatorAddress,
            details: "",
            amount: AmountDecimal(value: amount ?? 0.0),
            fees: [],
            timestamp: itemTimestamp,
            type: type,
            reason: nil,
            context: nil
        )
    }
}
