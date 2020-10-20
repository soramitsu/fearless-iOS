import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto

struct WalletCommonConfigurator {

    let localizationManager: LocalizationManagerProtocol
    let networkType: SNAddressType

    init(localizationManager: LocalizationManagerProtocol, networkType: SNAddressType) {
        self.localizationManager = localizationManager
        self.networkType = networkType
    }

    func configure(builder: CommonWalletBuilderProtocol) {
        let language = WalletLanguage(rawValue: localizationManager.selectedLocalization)
            ?? WalletLanguage.defaultLanguage

        let decoratorFactory = WalletCommandDecoratorFactory(localizationManager: localizationManager)

        let singleProviderIdFactory = WalletSingleProviderIdFactory(addressType: networkType)
        builder
            .with(language: language)
            .with(commandDecoratorFactory: decoratorFactory)
            .with(logger: Logger.shared)
            .with(amountFormatterFactory: AmountFormatterFactory())
            .with(singleProviderIdentifierFactory: singleProviderIdFactory)
    }
}
