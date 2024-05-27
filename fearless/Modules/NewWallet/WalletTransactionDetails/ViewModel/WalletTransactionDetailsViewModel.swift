import Foundation
import UIKit

class WalletTransactionDetailsViewModel {
    let transaction: AssetTransactionData
    let transactionType: TransactionType

    let extrinsicHash: String
    let status: String
    let dateString: String?
    let statusIcon: UIImage?

    init(
        transaction: AssetTransactionData,
        transactionType: TransactionType,
        extrinsicHash: String,
        status: String,
        dateString: String?,
        statusIcon: UIImage?
    ) {
        self.transaction = transaction
        self.transactionType = transactionType
        self.extrinsicHash = extrinsicHash
        self.status = status
        self.dateString = dateString
        self.statusIcon = statusIcon
    }
}

class TransferTransactionDetailsViewModel: WalletTransactionDetailsViewModel {
    let from: String?
    let to: String?
    let amount: String?
    let fee: String?
    let total: String?

    init(
        transaction: AssetTransactionData,
        transactionType: TransactionType,
        extrinsicHash: String,
        status: String,
        dateString: String?,
        from: String?,
        to: String?,
        amount: String?,
        fee: String?,
        total: String?,
        statusIcon: UIImage?
    ) {
        self.from = from
        self.to = to
        self.amount = amount
        self.fee = fee
        self.total = total

        super.init(
            transaction: transaction,
            transactionType: transactionType,
            extrinsicHash: extrinsicHash,
            status: status,
            dateString: dateString,
            statusIcon: statusIcon
        )
    }
}

class RewardTransactionDetailsViewModel: WalletTransactionDetailsViewModel {
    let era: String
    let reward: String?
    let validator: String?

    init(
        transaction: AssetTransactionData,
        transactionType: TransactionType,
        extrinsicHash: String,
        status: String,
        dateString: String?,
        era: String,
        reward: String?,
        validator: String?,
        statusIcon: UIImage?
    ) {
        self.era = era
        self.reward = reward
        self.validator = validator

        super.init(
            transaction: transaction,
            transactionType: transactionType,
            extrinsicHash: extrinsicHash,
            status: status,
            dateString: dateString,
            statusIcon: statusIcon
        )
    }
}

class SlashTransactionDetailsViewModel: WalletTransactionDetailsViewModel {
    let era: String
    let slash: String?
    let validator: String?

    init(
        transaction: AssetTransactionData,
        transactionType: TransactionType,
        extrinsicHash: String,
        status: String,
        dateString: String?,
        era: String,
        slash: String?,
        validator: String?,
        statusIcon: UIImage?
    ) {
        self.era = era
        self.slash = slash
        self.validator = validator

        super.init(
            transaction: transaction,
            transactionType: transactionType,
            extrinsicHash: extrinsicHash,
            status: status,
            dateString: dateString,
            statusIcon: statusIcon
        )
    }
}

class ExtrinsicTransactionDetailsViewModel: WalletTransactionDetailsViewModel {
    let module: String?
    let call: String?
    let sender: String?
    let fee: String?

    init(
        transaction: AssetTransactionData,
        transactionType: TransactionType,
        extrinsicHash: String,
        status: String,
        dateString: String?,
        module: String?,
        call: String?,
        statusIcon: UIImage?,
        sender: String?,
        fee: String?
    ) {
        self.module = module
        self.call = call
        self.sender = sender
        self.fee = fee

        super.init(
            transaction: transaction,
            transactionType: transactionType,
            extrinsicHash: extrinsicHash,
            status: status,
            dateString: dateString,
            statusIcon: statusIcon
        )
    }
}
