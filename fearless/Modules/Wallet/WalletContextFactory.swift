import Foundation
import CommonWallet
import SoraKeystore
import RobinHood

protocol WalletContextFactoryProtocol {
    func createContext() throws -> CommonWalletContextProtocol
}

final class WalletContextFactory {
    let keychain: KeystoreProtocol
    let settings: SettingsManagerProtocol
    let applicationConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    init(keychain: KeystoreProtocol = Keychain(),
         settings: SettingsManagerProtocol = SettingsManager.shared,
         applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared,
         logger: LoggerProtocol = Logger.shared) {
        self.keychain = keychain
        self.settings = settings
        self.applicationConfig = applicationConfig
        self.logger = logger

        primitiveFactory = WalletPrimitiveFactory(keystore: keychain,
                                                  settings: settings)
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    func createContext() throws -> CommonWalletContextProtocol {
        let accountSettings = try primitiveFactory.createAccountSettings()

        logger.debug("Loading wallet account: \(accountSettings.accountId)")

        let networkFactory = WalletNetworkOperationFactory()

        let builder = CommonWalletBuilder.builder(with: accountSettings, networkOperationFactory: networkFactory)

        WalletCommonConfigurator().configure(builder: builder)
        WalletCommonStyleConfigurator().configure(builder: builder.styleBuilder)

        let accountListConfigurator = WalletAccountListConfigurator(logger: logger)
        accountListConfigurator.configure(builder: builder.accountListModuleBuilder)

        TransactionHistoryConfigurator().configure(builder: builder.historyModuleBuilder)

        let context = try builder.build()

        accountListConfigurator.context = context

        return context
    }
}
