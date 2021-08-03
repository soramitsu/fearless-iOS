import Foundation
import CommonWallet

final class TransferValidator: TransferValidating {
    func validate(
        info: TransferInfo,
        balances: [BalanceData],
        metadata: TransferMetaData
    ) throws -> TransferInfo {
        guard info.amount.decimalValue > 0 else {
            throw TransferValidatingError.zeroAmount
        }

        guard let balanceData = balances.first(where: { $0.identifier == info.asset }) else {
            throw TransferValidatingError.missingBalance(assetId: info.asset)
        }

        let totalFee: Decimal = info.fees.reduce(Decimal(0)) { result, fee in
            result + fee.value.decimalValue
        }

        let balanceContext = BalanceContext(context: balanceData.context ?? [:])

        let sendingAmount = info.amount.decimalValue
        let totalAmount = sendingAmount + totalFee

        let availableBalance = balanceContext.available
        let totalBalance = balanceContext.total
        let minimalBalance = balanceContext.minimalBalance

        guard totalAmount <= availableBalance else {
            throw TransferValidatingError.unsufficientFunds(
                assetId: info.asset,
                available: availableBalance
            )
        }

        guard totalBalance - totalFee >= minimalBalance else {
            throw FearlessTransferValidatingError.cantPayFee
        }

        let transferMetadataContext = TransferMetadataContext(context: metadata.context ?? [:])

        let receiverTotalAfterTransfer = transferMetadataContext.receiverBalance + sendingAmount
        guard receiverTotalAfterTransfer >= balanceContext.minimalBalance else {
            throw FearlessTransferValidatingError.receiverBalanceTooLow
        }

        return TransferInfo(
            source: info.source,
            destination: info.destination,
            amount: info.amount,
            asset: info.asset,
            details: info.details,
            fees: info.fees,
            context: balanceContext.toContext()
        )
    }
}
