import Foundation
import CommonWallet

final class WalletAccountListConfigurator {
    private let headerViewModel = WalletHeaderViewModel()

    var context: CommonWalletContextProtocol? {
        get {
            headerViewModel.walletContext
        }

        set {
            headerViewModel.walletContext = newValue
        }
    }

    let logger: LoggerProtocol

    init(logger: LoggerProtocol) {
        self.logger = logger
    }

    func configure(builder: AccountListModuleBuilderProtocol) {
        do {

            let localHeaderViewModel = headerViewModel

            var viewStyle = AccountListViewStyle(refreshIndicatorStyle: UIColor.iconTintColor)
            viewStyle.backgroundImage = R.image.backgroundImage()

            let assetStyleFactory = AssetStyleFactory()
            let amountFormatterFactory = AmountFormatterFactory()
            let viewModelFactory = WalletAssetViewModelFactory(cellIdentifier: builder.assetCellIdentifier,
                                                               assetCellStyleFactory: assetStyleFactory,
                                                               amountFormatterFactory: amountFormatterFactory)

            try builder
            .with(minimumContentHeight: localHeaderViewModel.itemHeight)
                .inserting(viewModelFactory: { localHeaderViewModel }, at: 0)
            .with(cellNib: UINib(resource: R.nib.walletAccountHeaderView),
                  for: localHeaderViewModel.cellReuseIdentifier)
            .withActions(cellNib: UINib(resource: R.nib.walletActionsCell))
            .with(listViewModelFactory: viewModelFactory)
            .with(assetCellStyleFactory: assetStyleFactory)
            .with(viewStyle: viewStyle)
        } catch {
            logger.error("Can't customize account list: \(error)")
        }
    }
}
