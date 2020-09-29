import Foundation
import CommonWallet
import RobinHood
import SoraFoundation

final class WalletAssetViewModelFactory {
    let cellIdentifier: String
    let assetCellStyleFactory: AssetCellStyleFactoryProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol

    init(cellIdentifier: String,
         assetCellStyleFactory: AssetCellStyleFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol) {
        self.cellIdentifier = cellIdentifier
        self.assetCellStyleFactory = assetCellStyleFactory
        self.amountFormatterFactory = amountFormatterFactory
    }
}

extension WalletAssetViewModelFactory: AccountListViewModelFactoryProtocol {
    func createAssetViewModel(for asset: WalletAsset,
                              balance: BalanceData,
                              commandFactory: WalletCommandFactoryProtocol,
                              locale: Locale) -> AssetViewModelProtocol? {
        let amountFormatter = amountFormatterFactory.createDisplayFormatter(for: asset)

        let decimalBalance = balance.balance.decimalValue
        let amount: String

        if let balanceString = amountFormatter.value(for: locale).string(from: decimalBalance as NSNumber) {
            amount = balanceString
        } else {
            amount = balance.balance.stringValue
        }

        let details: String

        if let platform = asset.platform?.value(for: locale) {
            details = "\(platform) \(asset.symbol)"
        } else {
            details = asset.name.value(for: locale)
        }

        let symbolViewModel: WalletImageViewModelProtocol?

        if let image = R.image.iconKsm() {
            symbolViewModel = WalletStaticImageViewModel(staticImage: image)
        } else {
            symbolViewModel = nil
        }

        let style = assetCellStyleFactory.createCellStyle(for: asset)

        return WalletAssetViewModel(cellReuseIdentifier: cellIdentifier,
                                    assetId: asset.identifier,
                                    amount: amount,
                                    symbol: nil,
                                    accessoryDetails: nil,
                                    imageViewModel: symbolViewModel,
                                    style: style,
                                    details: details,
                                    command: nil)
    }
}
