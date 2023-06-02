import Foundation
import SSFUtils
import UIKit
import CommonWallet

struct WalletTransactionHistoryCellViewModel {
    let transaction: AssetTransactionData
    let address: String
    let icon: UIImage?
    let transactionType: String
    let amountString: String
    let timeString: String
    let statusIcon: UIImage?
    let status: AssetTransactionStatus
    let incoming: Bool
    let imageViewModel: RemoteImageViewModel?
}
