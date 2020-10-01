import Foundation
import CommonWallet

final class WalletAccountListConfigurator {

    var context: CommonWalletContextProtocol? = nil

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func configure(builder: AccountListModuleBuilderProtocol) {
        do {

            var viewStyle = AccountListViewStyle(refreshIndicatorStyle: R.color.colorWhite()!)
            viewStyle.backgroundImage = R.image.backgroundImage()

            let assetStyleFactory = AssetStyleFactory()
            let amountFormatterFactory = AmountFormatterFactory()
            let viewModelFactory = WalletAssetViewModelFactory(cellIdentifier: builder.assetCellIdentifier,
                                                               assetCellStyleFactory: assetStyleFactory,
                                                               amountFormatterFactory: amountFormatterFactory)

            try builder
            .withActions(cellNib: UINib(resource: R.nib.walletActionsCell))
            .with(listViewModelFactory: viewModelFactory)
            .with(assetCellStyleFactory: assetStyleFactory)
            .with(viewStyle: viewStyle)
        } catch {
            logger.error("Can't customize account list: \(error)")
        }
    }
}
