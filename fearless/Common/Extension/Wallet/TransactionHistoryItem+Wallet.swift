import Foundation
import CommonWallet
import IrohaCrypto

extension TransactionHistoryItem {
    static func createFromTransferInfo(_ info: TransferInfo,
                                       transactionHash: Data,
                                       networkType: SNAddressType,
                                       addressFactory: SS58AddressFactoryProtocol) throws
        -> TransactionHistoryItem {
        let senderAccountId = try Data(hexString: info.source)
        let receiverAccountId = try Data(hexString: info.destination)

        let sender = try addressFactory.address(fromPublicKey: AccountIdWrapper(rawData: senderAccountId),
                                                type: networkType)

        let receiver = try addressFactory.address(fromPublicKey: AccountIdWrapper(rawData: receiverAccountId),
                                                  type: networkType)

        let totalFee = info.fees.reduce(Decimal(0)) { (total, fee) in total + fee.value.decimalValue }

        let timestamp = Int64(Date().timeIntervalSince1970)

        return TransactionHistoryItem(sender: sender,
                                      receiver: receiver,
                                      status: .pending,
                                      txHash: transactionHash.toHex(includePrefix: true),
                                      timestamp: timestamp,
                                      amount: info.amount.stringValue,
                                      fee: totalFee.stringWithPointSeparator,
                                      blockNumber: nil,
                                      txIndex: nil)
    }
}

extension TransactionHistoryItem.Status {
    var walletValue: AssetTransactionStatus {
        switch self {
        case .success:
            return .commited
        case .failed:
            return .rejected
        case .pending:
            return .pending
        }
    }
}
