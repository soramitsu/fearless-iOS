import Foundation
import CommonWallet

final class AssetDetailsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = ""
    var itemHeight: CGFloat = 0.0
    var command: WalletCommandProtocol? { nil }

    let amount: String
    let price: String
    let priceChange: String
    let totalVolume: String

    let leftTitle: String
    let leftDetails: String

    let rightTitle: String
    let rightDetails: String

    init(amount: String,
         price: String,
         priceChange: String,
         totalVolume: String,
         leftTitle: String,
         leftDetails: String,
         rightTitle: String,
         rightDetails: String) {
        self.amount = amount
        self.price = price
        self.priceChange = priceChange
        self.totalVolume = totalVolume
        self.leftTitle = leftTitle
        self.leftDetails = leftDetails
        self.rightTitle = rightTitle
        self.rightDetails = rightDetails
    }
}
