import Foundation
import CommonWallet

enum WalletPriceChangeViewModel {
    case goingUp(displayValue: String)
    case goingDown(displayValue: String)
}

final class WalletAssetViewModel: AssetViewModelProtocol {
    var itemHeight: CGFloat { WalletAccountListConstants.assetCellHeight }
    var cellReuseIdentifier: String { WalletAccountListConstants.assetCellId }
    let assetId: String
    let amount: String
    let symbol: String?
    let details: String
    let accessoryDetails: String?
    let imageViewModel: WalletImageViewModelProtocol?
    let style: AssetCellStyle
    let command: WalletCommandProtocol?
    let priceChangeViewModel: WalletPriceChangeViewModel

    let platform: String

    init(assetId: String,
         amount: String,
         symbol: String?,
         accessoryDetails: String?,
         imageViewModel: WalletImageViewModelProtocol?,
         style: AssetCellStyle,
         platform: String,
         details: String,
         priceChangeViewModel: WalletPriceChangeViewModel,
         command: WalletCommandProtocol?) {
        self.assetId = assetId
        self.amount = amount
        self.symbol = symbol
        self.accessoryDetails = accessoryDetails
        self.imageViewModel = imageViewModel
        self.style = style
        self.platform = platform
        self.details = details
        self.priceChangeViewModel = priceChangeViewModel
        self.command = command
    }
}
