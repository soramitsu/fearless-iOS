import Foundation
import RobinHood

protocol ChainRegistryProtocol: AnyObject {
    func syncUp()
}

final class ChainRegistry {
    let runtimeProviderPool: RuntimeProviderPoolProtocol
    let connectionPool: ConnectionPoolProtocol
    let chainSyncService: ChainSyncServiceProtocol
    let chainProvider: StreamableProvider<ChainModel>
    let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
    }
}

extension ChainRegistry: ChainRegistryProtocol {
    func syncUp() {
        chainSyncService.syncUp()
    }
}
