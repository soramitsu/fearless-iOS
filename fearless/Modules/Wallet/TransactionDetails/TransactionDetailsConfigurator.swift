import Foundation
import CommonWallet

final class TransactionDetailsConfigurator {
    let viewModelFactory: TransactionDetailsViewModelFactory

    init(address: String,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         assets: [WalletAsset]) {
        viewModelFactory = TransactionDetailsViewModelFactory(address: address,
                                                              assets: assets,
                                                              dateFormatter: DateFormatter.txDetails,
                                                              amountFormatterFactory: amountFormatterFactory)
    }

    func configure(builder: TransactionDetailsModuleBuilderProtocol) {
        builder
            .with(viewModelFactory: viewModelFactory)
            .with(viewBinder: TransactionDetailsFormViewModelBinder())
            .with(definitionFactory: WalletFearlessDefinitionFactory())
            .with(accessoryViewFactory: TransactionDetailsAccessoryViewFactory.self)
    }
}
