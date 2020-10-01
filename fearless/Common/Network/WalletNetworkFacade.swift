import Foundation
import CommonWallet
import IrohaCrypto

final class WalletNetworkFacade {
    let nodeOperationFactory: WalletNetworkOperationFactoryProtocol
    let subscanOperationFactory: SubscanOperationFactoryProtocol
    let address: String
    let networkType: SNAddressType
    let totalPriceAssetId: WalletAssetId

    init(nodeOperationFactory: WalletNetworkOperationFactoryProtocol,
         subscanOperationFactory: SubscanOperationFactoryProtocol,
         address: String,
         networkType: SNAddressType,
         totalPriceAssetId: WalletAssetId) {
        self.nodeOperationFactory = nodeOperationFactory
        self.subscanOperationFactory = subscanOperationFactory
        self.address = address
        self.networkType = networkType
        self.totalPriceAssetId = totalPriceAssetId
    }
}
