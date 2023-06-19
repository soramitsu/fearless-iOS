import Foundation
import CommonWallet
import SoraFoundation
import SSFModels

protocol WalletTransactionDetailsViewModelFactoryProtocol {
    func buildViewModel(
        transaction: AssetTransactionData,
        locale: Locale
    ) -> WalletTransactionDetailsViewModel?
}

class WalletTransactionDetailsViewModelFactory: WalletTransactionDetailsViewModelFactoryProtocol {
    let accountAddress: String
    let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let asset: AssetModel

    init(
        accountAddress: String,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol,
        asset: AssetModel
    ) {
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
        self.asset = asset
        self.accountAddress = accountAddress
    }

    // swiftlint:disable function_body_length
    func buildViewModel(
        transaction: AssetTransactionData,
        locale: Locale
    ) -> WalletTransactionDetailsViewModel? {
        guard let transactionType = TransactionType(rawValue: transaction.type) else {
            return nil
        }

        let hash = transaction.reason ?? ""
        var status: String
        var statusIcon: UIImage?
        switch transaction.status {
        case .pending:
            status = R.string.localizable.transactionStatusPending(preferredLanguages: locale.rLanguages)
            statusIcon = R.image.iconPending()
        case .commited:
            status = R.string.localizable.transactionStatusCompleted(preferredLanguages: locale.rLanguages)
            statusIcon = R.image.iconValid()
        case .rejected:
            status = R.string.localizable.transactionStatusFailed(preferredLanguages: locale.rLanguages)
            statusIcon = R.image.iconTxFailed()
        }

        let date = Date(timeIntervalSince1970: TimeInterval(transaction.timestamp))
        let dateString = DateFormatter.txDetails.value(for: locale).string(from: date)

        let tokenFormatter = assetBalanceFormatterFactory
            .createTokenFormatter(for: asset.displayInfo, usageCase: .detailsCrypto)
            .value(for: locale)

        switch transactionType {
        case .incoming, .outgoing:

            let from = transactionType == .outgoing ? accountAddress : transaction.peerName
            let to = transactionType == .incoming ? accountAddress : transaction.peerName
            let amountString = tokenFormatter.stringFromDecimal(transaction.amount.decimalValue)
            let fee: Decimal = transaction.fees.map(\.amount.decimalValue).reduce(0, +)
            let feeString = tokenFormatter.stringFromDecimal(fee)

            let total = transaction.amount.decimalValue + fee
            let totalString = tokenFormatter.stringFromDecimal(total)

            return TransferTransactionDetailsViewModel(
                transaction: transaction,
                transactionType: transactionType,
                extrinsicHash: hash,
                status: status,
                dateString: dateString,
                from: from,
                to: to,
                amount: amountString,
                fee: feeString,
                total: totalString,
                statusIcon: statusIcon
            )
        case .reward:
            let era = transaction.details
            let reward = tokenFormatter.stringFromDecimal(transaction.amount.decimalValue)

            return RewardTransactionDetailsViewModel(
                transaction: transaction,
                transactionType: transactionType,
                extrinsicHash: hash,
                status: status,
                dateString: dateString,
                era: era,
                reward: reward,
                validator: transaction.peerFirstName,
                statusIcon: statusIcon
            )
        case .slash:
            let era = transaction.details
            let slash = tokenFormatter.stringFromDecimal(transaction.amount.decimalValue)

            return SlashTransactionDetailsViewModel(
                transaction: transaction,
                transactionType: transactionType,
                extrinsicHash: hash,
                status: status,
                dateString: dateString,
                era: era,
                slash: slash,
                validator: transaction.peerFirstName,
                statusIcon: statusIcon
            )
        case .extrinsic:
            let module = transaction.peerFirstName
            let call = transaction.peerLastName
            let sender = transaction.peerId

            return ExtrinsicTransactionDetailsViewModel(
                transaction: transaction,
                transactionType: transactionType,
                extrinsicHash: hash,
                status: status,
                dateString: dateString,
                module: module,
                call: call,
                statusIcon: statusIcon,
                sender: sender
            )
        case .swap:
            let from = transactionType == .outgoing ? accountAddress : transaction.peerName
            let to = transactionType == .incoming ? accountAddress : transaction.peerName
            let amountString = tokenFormatter.stringFromDecimal(transaction.amount.decimalValue)
            let fee: Decimal = transaction.fees.map(\.amount.decimalValue).reduce(0, +)
            let feeString = tokenFormatter.stringFromDecimal(fee)

            let total = transaction.amount.decimalValue + fee
            let totalString = tokenFormatter.stringFromDecimal(total)

            return TransferTransactionDetailsViewModel(
                transaction: transaction,
                transactionType: transactionType,
                extrinsicHash: hash,
                status: status,
                dateString: dateString,
                from: from,
                to: to,
                amount: amountString,
                fee: feeString,
                total: totalString,
                statusIcon: statusIcon
            )
        case .unused:
            return nil
        }
    }
}
