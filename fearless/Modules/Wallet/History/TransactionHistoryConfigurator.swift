import Foundation
import CommonWallet

struct TransactionHistoryConfigurator {
    func configure(builder: HistoryModuleBuilderProtocol) {
        builder
            .with(emptyStateDataSource: WalletEmptyStateDataSource.history)
            .with(historyViewStyle: HistoryViewStyle.fearless)
            .with(supportsFilter: false)
    }
}
