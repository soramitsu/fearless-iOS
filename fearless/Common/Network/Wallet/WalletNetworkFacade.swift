import Foundation
import CommonWallet
import IrohaCrypto
import RobinHood

final class WalletNetworkFacade {
    let storageFacade: StorageFacadeProtocol
    let accountSettings: WalletAccountSettingsProtocol
    let nodeOperationFactory: WalletNetworkOperationFactoryProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    let address: String
    let networkType: SNAddressType
    let totalPriceAssetId: WalletAssetId
    let runtimeCodingService: RuntimeCodingServiceProtocol
    let chainStorage: AnyDataProviderRepository<ChainStorageItem>
    let localStorageRequestFactory: LocalStorageRequestFactoryProtocol
    let localStorageIdFactory: ChainStorageIdFactoryProtocol
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>
    let contactsOperationFactory: WalletContactOperationFactoryProtocol
    let accountsRepository: AnyDataProviderRepository<ManagedAccountItem>

    init(
        storageFacade: StorageFacadeProtocol,
        accountSettings: WalletAccountSettingsProtocol,
        nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
        subscanOperationFactory: SubscanOperationFactoryProtocol,
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol,
        chainStorage: AnyDataProviderRepository<ChainStorageItem>,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        localStorageRequestFactory: LocalStorageRequestFactoryProtocol,
        localStorageIdFactory: ChainStorageIdFactoryProtocol,
        txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
        contactsOperationFactory: WalletContactOperationFactoryProtocol,
        accountsRepository: AnyDataProviderRepository<ManagedAccountItem>,
        address: String,
        networkType: SNAddressType,
        totalPriceAssetId: WalletAssetId
    ) {
        self.storageFacade = storageFacade
        self.accountSettings = accountSettings
        self.nodeOperationFactory = nodeOperationFactory
        self.subscanOperationFactory = subscanOperationFactory
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.address = address
        self.networkType = networkType
        self.totalPriceAssetId = totalPriceAssetId
        self.chainStorage = chainStorage
        self.runtimeCodingService = runtimeCodingService
        self.localStorageRequestFactory = localStorageRequestFactory
        self.localStorageIdFactory = localStorageIdFactory
        self.txStorage = txStorage
        self.contactsOperationFactory = contactsOperationFactory
        self.accountsRepository = accountsRepository
    }
}
