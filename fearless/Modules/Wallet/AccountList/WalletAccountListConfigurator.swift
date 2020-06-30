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

            try builder
            .with(minimumContentHeight: localHeaderViewModel.itemHeight)
                .inserting(viewModelFactory: { localHeaderViewModel }, at: 0)
            .with(cellNib: UINib(resource: R.nib.walletAccountHeaderView),
                  for: localHeaderViewModel.cellReuseIdentifier)
        } catch {
            logger.error("Can't customize account list: \(error)")
        }
    }
}
