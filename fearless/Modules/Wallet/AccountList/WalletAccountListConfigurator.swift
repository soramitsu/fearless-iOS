import Foundation
import CommonWallet

final class WalletAccountListConfigurator {
    let logger: LoggerProtocol

    let viewModelFactory: WalletAssetViewModelFactory
    let assetStyleFactory: AssetStyleFactory

    init(address: String,
         chain: Chain,
         priceAsset: WalletAsset,
         purchaseProvider: PurchaseProviderProtocol,
         logger: LoggerProtocol) {
        self.logger = logger

        assetStyleFactory = AssetStyleFactory()

        let amountFormatterFactory = AmountFormatterFactory()
        let accountCommandFactory = WalletSelectAccountCommandFactory()

        viewModelFactory = WalletAssetViewModelFactory(address: address,
                                                       chain: chain,
                                                       assetCellStyleFactory: assetStyleFactory,
                                                       amountFormatterFactory: amountFormatterFactory,
                                                       priceAsset: priceAsset,
                                                       accountCommandFactory: accountCommandFactory,
                                                       purchaseProvider: purchaseProvider)
    }

    func configure(builder: AccountListModuleBuilderProtocol) {
        do {

            var viewStyle = AccountListViewStyle(refreshIndicatorStyle: R.color.colorWhite()!)
            viewStyle.backgroundImage = R.image.backgroundImage()

            try builder
            .with(cellNib: UINib(resource: R.nib.walletTotalPriceCell),
                  for: WalletAccountListConstants.totalPriceCellId)
            .with(cellNib: UINib(resource: R.nib.walletAssetCell),
                  for: WalletAccountListConstants.assetCellId)
            .with(cellNib: UINib(resource: R.nib.walletActionsCell),
                  for: WalletAccountListConstants.actionsCellId)
            .with(listViewModelFactory: viewModelFactory)
            .with(assetCellStyleFactory: assetStyleFactory)
            .with(viewStyle: viewStyle)
        } catch {
            logger.error("Can't customize account list: \(error)")
        }
    }
}
