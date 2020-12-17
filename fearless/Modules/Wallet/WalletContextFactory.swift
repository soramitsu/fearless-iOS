import Foundation
import CommonWallet
import SoraKeystore
import RobinHood
import IrohaCrypto
import SoraFoundation

enum WalletContextFactoryError: Error {
    case missingAccount
    case missingPriceAsset
    case missingConnection
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
        guard let selectedAccount = SettingsManager.shared.selectedAccount else {
            throw WalletContextFactoryError.missingAccount
        }

        guard let connection = WebSocketService.shared.connection else {
            throw WalletContextFactoryError.missingConnection
        }

        let accountSettings = try primitiveFactory.createAccountSettings()

        guard let priceAsset = accountSettings.assets
            .first(where: { $0.identifier == WalletAssetId.usd.rawValue }) else {
            throw WalletContextFactoryError.missingPriceAsset
        }

        let amountFormatterFactory = AmountFormatterFactory()

        logger.debug("Loading wallet account: \(selectedAccount.address)")

        let networkType = SettingsManager.shared.selectedConnection.type

        let accountSigner = SigningWrapper(keystore: Keychain(), settings: SettingsManager.shared)
        let dummySigner = try DummySigner(cryptoType: selectedAccount.cryptoType)

        let nodeOperationFactory = WalletNetworkOperationFactory(engine: connection,
                                                                 accountSettings: accountSettings,
                                                                 cryptoType: selectedAccount.cryptoType,
                                                                 accountSigner: accountSigner,
                                                                 dummySigner: dummySigner)

        let subscanOperationFactory = SubscanOperationFactory()

        let substrateStorageFacade = SubstrateDataStorageFacade.shared
        let chainStorage: CoreDataRepository<ChainStorageItem, CDChainStorageItem> =
            substrateStorageFacade.createRepository()
        let localStorageIdFactory = try ChainStorageIdFactory(chain: networkType.chain)

        let txFilter = NSPredicate.filterTransactionsBy(address: selectedAccount.address)
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository(filter: txFilter)

        let contactOperationFactory = WalletContactOperationFactory(storageFacade: substrateStorageFacade,
                                                                    targetAddress: selectedAccount.address)

        let accountStorage: CoreDataRepository<ManagedAccountItem, CDAccountItem> =
            UserDataStorageFacade.shared
            .createRepository(filter: NSPredicate.filterAccountBy(networkType: networkType),
                              sortDescriptors: [NSSortDescriptor.accountsByOrder],
                              mapper: AnyCoreDataMapper(ManagedAccountItemMapper()))

        let networkFacade = WalletNetworkFacade(accountSettings: accountSettings,
                                                nodeOperationFactory: nodeOperationFactory,
                                                subscanOperationFactory: subscanOperationFactory,
                                                chainStorage: AnyDataProviderRepository(chainStorage),
                                                localStorageIdFactory: localStorageIdFactory,
                                                txStorage: AnyDataProviderRepository(txStorage),
                                                contactsOperationFactory: contactOperationFactory,
                                                accountsRepository: AnyDataProviderRepository(accountStorage),
                                                address: selectedAccount.address,
                                                networkType: networkType,
                                                totalPriceAssetId: .usd)

        let builder = CommonWalletBuilder.builder(with: accountSettings,
                                                  networkOperationFactory: networkFacade)

        let localizationManager = LocalizationManager.shared

        let tokenAssets = accountSettings.assets.filter { $0.identifier != priceAsset.identifier }

        WalletCommonConfigurator(localizationManager: localizationManager,
                                 networkType: networkType,
                                 account: selectedAccount,
                                 assets: tokenAssets).configure(builder: builder)
        WalletCommonStyleConfigurator().configure(builder: builder.styleBuilder)

        let purchaseProvider = PurchaseAggregator.defaultAggregator()
        let accountListConfigurator = WalletAccountListConfigurator(address: selectedAccount.address,
                                                                    chain: networkType.chain,
                                                                    priceAsset: priceAsset,
                                                                    purchaseProvider: purchaseProvider,
                                                                    logger: logger)

        accountListConfigurator.configure(builder: builder.accountListModuleBuilder)

        let assetDetailsConfigurator = AssetDetailsConfigurator(address: selectedAccount.address,
                                                                chain: networkType.chain,
                                                                purchaseProvider: purchaseProvider,
                                                                priceAsset: priceAsset)
        assetDetailsConfigurator.configure(builder: builder.accountDetailsModuleBuilder)

        TransactionHistoryConfigurator(amountFormatterFactory: amountFormatterFactory,
                                       assets: accountSettings.assets)
            .configure(builder: builder.historyModuleBuilder)

        TransactionDetailsConfigurator(address: selectedAccount.address,
                                       amountFormatterFactory: amountFormatterFactory,
                                       assets: accountSettings.assets)
            .configure(builder: builder.transactionDetailsModuleBuilder)

        let transferConfigurator = TransferConfigurator(assets: accountSettings.assets,
                                                        amountFormatterFactory: amountFormatterFactory,
                                                        localizationManager: localizationManager)
        transferConfigurator.configure(builder: builder.transferModuleBuilder)

        let confirmConfigurator = TransferConfirmConfigurator(assets: accountSettings.assets,
                                                              amountFormatterFactory: amountFormatterFactory)
        confirmConfigurator.configure(builder: builder.transferConfirmationBuilder)

        let contactsConfigurator = ContactsConfigurator(networkType: networkType)
        contactsConfigurator.configure(builder: builder.contactsModuleBuilder)

        let receiveConfigurator = ReceiveConfigurator(account: selectedAccount,
                                                      chain: networkType.chain,
                                                      assets: tokenAssets,
                                                      localizationManager: localizationManager)
        receiveConfigurator.configure(builder: builder.receiveModuleBuilder)

        let invoiceScanConfigurator = InvoiceScanConfigurator(networkType: networkType)
        invoiceScanConfigurator.configure(builder: builder.invoiceScanModuleBuilder)

        let context = try builder.build()

        subscribeContextToLanguageSwitch(context,
                                         localizationManager: localizationManager,
                                         logger: logger)

        transferConfigurator.commandFactory = context
        confirmConfigurator.commandFactory = context
        receiveConfigurator.commandFactory = context

        return context
    }
}
