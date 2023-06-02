import Foundation
import XNetworking
import BigInt
import CommonWallet
import IrohaCrypto
import SSFUtils

extension TxHistoryItem: WalletRemoteHistoryItemProtocol {
    var identifier: String { id }
    var itemBlockNumber: UInt64 { 0 }
    var itemExtrinsicIndex: UInt16 { 0 }
    var extrinsicHash: String? { id }
    var itemTimestamp: Int64 {
        Int64(timestamp) ?? 0
    }

    var label: WalletRemoteHistorySourceLabel {
        .extrinsics
    }

    func createTransactionForAddress(
        _ address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        var dict = [String: JSON]()

        for element in data ?? [] {
            dict[element.paramName] = JSON.stringValue(element.paramValue)
        }

        let json: JSON = .dictionaryValue(dict)

        if let rewardOrSlash = try? json.map(to: SubqueryRewardOrSlash.self) {
            return createTransactionForRewardOrSlash(rewardOrSlash, asset: asset)
        }

        if let transfer = try? json.map(to: SoraSubqueryTransfer.self) {
            return createTransactionForTransfer(
                transfer,
                address: address,
                chain: chain,
                asset: asset
            )
        }

        if let swap = try? json.map(to: SubquerySwap.self) {
            return createTransactionForSwap(swap)
        }

        if let liquidity = try? json.map(to: SubqueryLiquidity.self) {
            return createTransactionForLiquidity(
                liquidity,
                asset: asset
            )
        }

        if let referral = try? json.map(to: SubqueryReferral.self) {
            return createTransactionForReferral(
                referral,
                address: address,
                asset: asset
            )
        }

        if let depositLiquidityData = createDepositLiquidityAssetTransaction(
            asset: asset
        ) {
            return depositLiquidityData
        }

        return createUnknownAssetTransaction(asset: asset)
    }

    // MARK: - Private methods

    private func createUnknownAssetTransaction(
        asset: AssetModel
    ) -> AssetTransactionData {
        AssetTransactionData(
            transactionId: identifier,
            status: .pending,
            assetId: asset.identifier,
            peerId: "",
            peerFirstName: nil,
            peerLastName: nil,
            peerName: "",
            details: "",
            amount: AmountDecimal(value: 0),
            fees: [],
            timestamp: itemTimestamp,
            type: TransactionType.unused.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForTransfer(
        _ transfer: SoraSubqueryTransfer,
        address: String,
        chain: ChainModel,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status = success ? AssetTransactionStatus.commited : AssetTransactionStatus.rejected

        let peerAddress = transfer.sender == address ? transfer.receiver : transfer.sender

        let peerAccountId = try? AddressFactory.accountId(
            from: address,
            chain: chain
        )

        let amountDecimal = Decimal(string: transfer.amount) ?? .zero
        let feeDecimal = Decimal(string: networkFee) ?? .zero

        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let type = transfer.sender == address ? TransactionType.outgoing : TransactionType.incoming

        let context: [String: String]?

        if let extrinsicHash = self.extrinsicHash {
            context = [TransactionContextKeys.extrinsicHash: extrinsicHash]
        } else {
            context = nil
        }

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: transfer.assetId,
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
            context: context
        )
    }

    private func createTransactionForSwap(
        _ swap: SubquerySwap
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        let amountDecimal = Decimal(string: swap.targetAssetAmount) ?? .zero

        let feeDecimal = Decimal(string: networkFee) ?? .zero
        let fee = AssetTransactionFee(
            identifier: swap.targetAssetId,
            assetId: swap.targetAssetId,
            amount: AmountDecimal(value: feeDecimal),
            context: nil
        )

        let lpFeeDecimal = Decimal(string: swap.liquidityProviderFee) ?? .zero
        let lpFee = AssetTransactionFee(
            identifier: swap.baseAssetId,
            assetId: swap.baseAssetId,
            amount: AmountDecimal(value: lpFeeDecimal),
            context: ["type": TransactionType.swap.rawValue]
        )
        // Selected market: empty: smart; else first?
        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: swap.targetAssetId,
            peerId: swap.baseAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: swap.selectedMarket,
            details: swap.baseAssetAmount,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee, lpFee],
            timestamp: itemTimestamp,
            type: TransactionType.swap.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForRewardOrSlash(
        _ rewardOrSlash: SubqueryRewardOrSlash,
        asset: AssetModel
    ) -> AssetTransactionData {
        let amount = Decimal.fromSubstrateAmount(
            BigUInt(rewardOrSlash.amount) ?? 0,
            precision: Int16(asset.precision)
        ) ?? 0.0

        let type = rewardOrSlash.isReward ? TransactionType.reward.rawValue : TransactionType.slash.rawValue

        let validatorAddress = rewardOrSlash.validator ?? ""

        let context: [String: String]?

        if let era = rewardOrSlash.era {
            context = [TransactionContextKeys.era: String(era)]
        } else {
            context = nil
        }

        return AssetTransactionData(
            transactionId: identifier,
            status: .commited,
            assetId: asset.identifier,
            peerId: validatorAddress,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: validatorAddress,
            details: "",
            amount: AmountDecimal(value: amount),
            fees: [],
            timestamp: itemTimestamp,
            type: type,
            reason: nil,
            context: context
        )
    }

    private func createDepositLiquidityAssetTransaction(
        asset: AssetModel
    ) -> AssetTransactionData? {
        var dict = [String: JSON]()

        if let data = nestedData?.first(where: {
            $0.module == "poolXYK" && $0.method == "depositLiquidity"
        }
        ) {
            for element in data.data {
                dict[element.paramName] = JSON.stringValue(element.paramValue)
            }

            let json: JSON = .dictionaryValue(dict)
            if let extrinsic = try? json.map(to: SubqueryCreatePoolLiquidity.self) {
                return createTransactionForCreateLiquidityPool(
                    extrinsic,
                    asset: asset
                )
            }
        }
        return nil
    }

    private func createTransactionForLiquidity(
        _ liquidity: SubqueryLiquidity,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        let amountDecimal = Decimal(string: liquidity.targetAssetAmount) ?? .zero
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: Decimal(string: networkFee) ?? .zero),
            context: nil
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: liquidity.targetAssetId,
            peerId: liquidity.baseAssetId,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: liquidity.baseAssetId,
            details: liquidity.baseAssetAmount,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: TransactionType.unused.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForCreateLiquidityPool(
        _ liquidity: SubqueryCreatePoolLiquidity,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        let amountDecimal = Decimal(string: liquidity.inputADesired) ?? .zero
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: Decimal(string: networkFee) ?? .zero),
            context: nil
        )

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: liquidity.inputAssetA,
            peerId: liquidity.inputAssetB,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: liquidity.inputAssetB,
            details: liquidity.inputBDesired,
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: TransactionLiquidityType.deposit.rawValue,
            reason: nil,
            context: nil
        )
    }

    private func createTransactionForReferral(
        _ referral: SubqueryReferral,
        address: String,
        asset: AssetModel
    ) -> AssetTransactionData {
        let status: AssetTransactionStatus = success ? .commited : .rejected
        let amountDecimal = Decimal(string: referral.amount ?? "") ?? .zero
        let fee = AssetTransactionFee(
            identifier: asset.identifier,
            assetId: asset.identifier,
            amount: AmountDecimal(value: Decimal(string: networkFee) ?? .zero),
            context: nil
        )

        var type = ReferralMethodType(fromRawValue: method)

        if type == .setReferrer, referral.to == address {
            type = .setReferral
        }

        let context: [String: String]? = [
            TransactionContextKeys.blockHash: blockHash,
            TransactionContextKeys.sender: referral.from,
            TransactionContextKeys.referral: referral.from,
            TransactionContextKeys.referrer: referral.to,
            TransactionContextKeys.referralTransactionType: type.rawValue
        ]

        return AssetTransactionData(
            transactionId: identifier,
            status: status,
            assetId: asset.identifier,
            peerId: referral.to,
            peerFirstName: nil,
            peerLastName: nil,
            peerName: nil,
            details: "",
            amount: AmountDecimal(value: amountDecimal),
            fees: [fee],
            timestamp: itemTimestamp,
            type: TransactionType.unused.rawValue,
            reason: nil,
            context: context
        )
    }
}
