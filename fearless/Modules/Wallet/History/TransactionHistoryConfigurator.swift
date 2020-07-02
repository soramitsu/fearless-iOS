import Foundation
import CommonWallet

struct TransactionHistoryConfigurator {
    func configure(builder: HistoryModuleBuilderProtocol) {
        builder
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(supportsFilter: false)
    }
}
