import Foundation
import CommonWallet

final class WalletTotalPriceViewModel: AssetViewModelProtocol {
    var cellReuseIdentifier: String { WalletAccountListConstants.totalPriceCellId }
    var itemHeight: CGFloat { WalletAccountListConstants.totalPriceHeight }

    let assetId: String
    let details: String
    let amount: String
    let symbol: String? = nil
    let accessoryDetails: String? = nil
    let imageViewModel: WalletImageViewModelProtocol?

    let style: AssetCellStyle

    let command: WalletCommandProtocol?
    let accountCommand: WalletCommandProtocol?

    init(assetId: String,
         details: String,
         amount: String,
         imageViewModel: WalletImageViewModelProtocol?,
         style: AssetCellStyle,
         command: WalletCommandProtocol?,
         accountCommand: WalletCommandProtocol?) {
        self.assetId = assetId
        self.details = details
        self.amount = amount
        self.command = command
        self.imageViewModel = imageViewModel
        self.accountCommand = accountCommand
        self.style = style
    }
}
