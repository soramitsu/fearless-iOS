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
    let txStorage: AnyDataProviderRepository<TransactionHistoryItem>

    init(accountSettings: WalletAccountSettingsProtocol,
         nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
         subscanOperationFactory: SubscanOperationFactoryProtocol,
         chainStorage: AnyDataProviderRepository<ChainStorageItem>,
         txStorage: AnyDataProviderRepository<TransactionHistoryItem>,
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
        self.txStorage = txStorage
    }
}
