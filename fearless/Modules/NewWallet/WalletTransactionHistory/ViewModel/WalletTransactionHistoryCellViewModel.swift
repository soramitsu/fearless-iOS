import Foundation
import FearlessUtils
import UIKit

struct WalletTransactionHistoryCellViewModel {
    let address: String
    let icon: DrawableIcon?
    let transactionType: String
    let amountString: String
    let timeString: String
    let statusIcon: UIImage?
}
