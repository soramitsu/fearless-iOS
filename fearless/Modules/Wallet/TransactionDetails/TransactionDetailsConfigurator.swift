import Foundation
import CommonWallet

final class TransactionDetailsConfigurator {
    let viewModelFactory: TransactionDetailsViewModelFactory

    init(amountFormatterFactory: NumberFormatterFactoryProtocol, assets: [WalletAsset]) {
        viewModelFactory = TransactionDetailsViewModelFactory(assets: assets,
                                                              dateFormatter: DateFormatter.txDetails,
                                                              amountFormatterFactory: amountFormatterFactory)
    }

    func configure(builder: TransactionDetailsModuleBuilderProtocol) {
        builder
            .with(viewModelFactory: viewModelFactory)
            .with(viewBinder: TransactionDetailsFormViewModelBinder())
    }
}
