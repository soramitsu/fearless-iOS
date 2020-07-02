import Foundation
import CommonWallet
import SoraFoundation

struct WalletCommonConfigurator {

    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    func configure(builder: CommonWalletBuilderProtocol) {
        let language = WalletLanguage(rawValue: localizationManager.selectedLocalization)
            ?? WalletLanguage.defaultLanguage
        builder
            .with(language: language)
            .with(commandDecoratorFactory: WalletCommandDecoratorFactory())
            .with(logger: Logger.shared)
    }
}
