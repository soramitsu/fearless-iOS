import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood

final class WalletNetworkFacade {
    let accountSettings: WalletAccountSettingsProtocol
    let nodeOperationFactory: WalletNetworkOperationFactoryProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let address: String
    let networkType: SNAddressType
    let totalPriceAssetId: WalletAssetId
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageIdFactory: ChainStorageIdFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let contactsOperationFactory: WalletContactOperationFactoryProtocol
    let accountsRepository: AnyDataProviderRepository<ManagedAccountItem>

    init(accountSettings: WalletAccountSettingsProtocol,
         nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
         subscanOperationFactory: SubscanOperationFactoryProtocol,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         localStorageIdFactory: ChainStorageIdFactoryProtocol,
         txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
         contactsOperationFactory: WalletContactOperationFactoryProtocol,
         accountsRepository: AnyDataProviderRepository<ManagedAccountItem>,
         address: String,
         networkType: SNAddressType,
         totalPriceAssetId: WalletAssetId) {
        self.accountSettings = accountSettings
        self.nodeOperationFactory = nodeOperationFactory
        self.subscanOperationFactory = subscanOperationFactory
        self.address = address
        self.networkType = networkType
        self.totalPriceAssetId = totalPriceAssetId
        self.chainStorage = chainStorage
        self.localStorageIdFactory = localStorageIdFactory
        self.txStorage = txStorage
        self.contactsOperationFactory = contactsOperationFactory
        self.accountsRepository = accountsRepository
    }
}
