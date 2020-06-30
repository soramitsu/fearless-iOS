import Foundation
import CommonWallet

final class WalletAssetViewModel: AssetViewModelProtocol {
    var itemHeight: CGFloat { 95.0 }
    let cellReuseIdentifier: String
    let assetId: String
    let amount: String
    let symbol: String?

    let details: String

    let accessoryDetails: String?
    let imageViewModel: WalletImageViewModelProtocol?
    let style: AssetCellStyle
    let command: WalletCommandProtocol?

    init(cellReuseIdentifier: String,
         assetId: String,
         amount: String,
         symbol: String?,
         accessoryDetails: String?,
         imageViewModel: WalletImageViewModelProtocol?,
         style: AssetCellStyle,
         details: String,
         command: WalletCommandProtocol?) {
        self.cellReuseIdentifier = cellReuseIdentifier
        self.assetId = assetId
        self.amount = amount
        self.symbol = symbol
        self.accessoryDetails = accessoryDetails
        self.imageViewModel = imageViewModel
        self.style = style
        self.details = details
        self.command = command
    }
}
