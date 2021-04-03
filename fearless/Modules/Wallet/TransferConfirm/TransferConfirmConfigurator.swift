import Foundation
import CommonWallet
import SoraFoundation

final class TransferConfirmConfigurator {
    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }

        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    let viewModelFactory: TransferConfirmViewModelFactory

    init(assets: [WalletAsset], amountFormatterFactory: NumberFormatterFactoryProtocol) {
        viewModelFactory = TransferConfirmViewModelFactory(
            assets: assets,
            amountFormatterFactory: amountFormatterFactory
        )
    }

    func configure(builder: TransferConfirmationModuleBuilderProtocol) {
        let title = LocalizableResource { locale in
            R.string.localizable.walletSendConfirmTitle(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(localizableTitle: title)
            .with(accessoryViewType: .onlyActionBar)
            .with(completion: .hide)
            .with(viewModelFactoryOverriding: viewModelFactory)
            .with(viewBinder: TransferConfirmBinder())
            .with(definitionFactory: WalletFearlessDefinitionFactory())
            .with(accessoryViewFactory: TransferConfirmAccessoryViewFactory.self)
    }
}
