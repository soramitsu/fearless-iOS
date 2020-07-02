import Foundation
import CommonWallet
import SoraKeystore
import RobinHood
import IrohaCrypto
import SoraFoundation

enum WalletContextFactoryError: Error {
    case missingNode
}

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

    private func subscribeContextToLanguageSwitch(_ context: CommonWalletContextProtocol,
                                                  localizationManager: LocalizationManagerProtocol,
                                                  logger: LoggerProtocol) {
        localizationManager.addObserver(with: context) { [weak context] (_, newLocalization) in
            if let newLanguage = WalletLanguage(rawValue: newLocalization) {
                do {
                    try context?.prepareLanguageSwitchCommand(with: newLanguage).execute()
                } catch {
                    logger.error("Error received when tried to change wallet language")
                }
            } else {
                logger.error("New selected language \(newLocalization) error is unsupported")
            }
        }
    }
}

extension WalletContextFactory: WalletContextFactoryProtocol {
    func createContext() throws -> CommonWalletContextProtocol {
        let accountSettings = try primitiveFactory.createAccountSettings()

        let publicKeyRaw = try Data(hexString: accountSettings.accountId)
        let publicKey = try SNPublicKey(rawData: publicKeyRaw)
        let address = try SS58AddressFactory().address(from: publicKey, type: .kusamaMain)
        logger.debug("Loading wallet account: \(address)")

        guard let node = ApplicationConfig.shared.nodes.first, let url = URL(string: node.address) else {
            throw WalletContextFactoryError.missingNode
        }

        let networkFactory = WalletNetworkOperationFactory(url: url, accountSettings: accountSettings)

        let builder = CommonWalletBuilder.builder(with: accountSettings, networkOperationFactory: networkFactory)

        let localizationManager = LocalizationManager.shared

        WalletCommonConfigurator(localizationManager: localizationManager).configure(builder: builder)
        WalletCommonStyleConfigurator().configure(builder: builder.styleBuilder)

        let accountListConfigurator = WalletAccountListConfigurator(logger: logger)
        accountListConfigurator.configure(builder: builder.accountListModuleBuilder)

        TransactionHistoryConfigurator().configure(builder: builder.historyModuleBuilder)

        let context = try builder.build()

        subscribeContextToLanguageSwitch(context,
                                         localizationManager: localizationManager,
                                         logger: logger)

        accountListConfigurator.context = context

        return context
    }
}
