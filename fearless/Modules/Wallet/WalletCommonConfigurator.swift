import Foundation
import CommonWallet
import SoraFoundation
import IrohaCrypto

struct WalletCommonConfigurator {
    let localizationManager: LocalizationManagerProtocol
    let networkType: SNAddressType
    let account: AccountItem
    let assets: [WalletAsset]

    init(
        localizationManager: LocalizationManagerProtocol,
        networkType: SNAddressType,
        account: AccountItem,
        assets: [WalletAsset]
    ) {
        self.localizationManager = localizationManager
        self.networkType = networkType
        self.account = account
        self.assets = assets
    }

    func configure(builder: CommonWalletBuilderProtocol) {
        let language = WalletLanguage(rawValue: localizationManager.selectedLocalization)
            ?? WalletLanguage.defaultLanguage

        let decoratorFactory = WalletCommandDecoratorFactory(
            localizationManager: localizationManager,
            dataStorageFacade: SubstrateDataStorageFacade.shared
        )

        let qrCoderFactory = WalletQRCoderFactory(
            networkType: networkType,
            publicKey: account.publicKeyData,
            username: account.username,
            assets: assets
        )

        let singleProviderIdFactory = WalletSingleProviderIdFactory(addressType: networkType)
        let transactionTypes = TransactionType.allCases.map { $0.toWalletType() }

        builder
            .with(language: language)
            .with(commandDecoratorFactory: decoratorFactory)
            .with(logger: Logger.shared)
            .with(transactionTypeList: transactionTypes)
            .with(amountFormatterFactory: AmountFormatterFactory())
            .with(singleProviderIdentifierFactory: singleProviderIdFactory)
            .with(qrCoderFactory: qrCoderFactory)
    }
}
