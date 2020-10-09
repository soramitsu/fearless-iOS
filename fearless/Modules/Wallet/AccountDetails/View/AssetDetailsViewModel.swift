import Foundation
import CommonWallet

final class AssetDetailsViewModel: WalletViewModelProtocol {
    var cellReuseIdentifier: String = ""
    var itemHeight: CGFloat = 0.0
    var command: WalletCommandProtocol? { nil }

    let title: String
    let imageViewModel: WalletImageViewModelProtocol?
    let amount: String
    let price: String
    let priceChangeViewModel: WalletPriceChangeViewModel
    let totalVolume: String

    let leftTitle: String
    let leftDetails: String

    let rightTitle: String
    let rightDetails: String

    init(title: String,
         imageViewModel: WalletImageViewModelProtocol?,
         amount: String,
         price: String,
         priceChangeViewModel: WalletPriceChangeViewModel,
         totalVolume: String,
         leftTitle: String,
         leftDetails: String,
         rightTitle: String,
         rightDetails: String) {
        self.title = title
        self.imageViewModel = imageViewModel
        self.amount = amount
        self.price = price
        self.priceChangeViewModel = priceChangeViewModel
        self.totalVolume = totalVolume
        self.leftTitle = leftTitle
        self.leftDetails = leftDetails
        self.rightTitle = rightTitle
        self.rightDetails = rightDetails
    }
}
