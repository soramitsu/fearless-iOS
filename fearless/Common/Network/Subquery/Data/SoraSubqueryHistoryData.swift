import Foundation

struct SoraWalletRemoteHistoryData {
    let historyItems: [WalletRemoteHistoryItemProtocol]
    let context: TransactionHistoryContext
}
