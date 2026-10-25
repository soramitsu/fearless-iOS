import Foundation
import SSFNetwork
import SSFUtils

public enum ChainRegistryAssembly {
    public static func createDefaultRegistry(
        chainsUrl: URL = ApplicationSourcesImpl.shared.chainsSourceUrl,
        chainTypesUrls: URL = ApplicationSourcesImpl.shared.chainTypesSourceUrl
    ) -> ChainRegistryProtocol {
        let chainSyncService = ChainSyncService(
            chainsUrl: chainsUrl,
            operationQueue: OperationQueue(),
            dataFetchFactory: NetworkOperationFactory()
        )

        let chainsTypesSyncService = ChainsTypesSyncService(
            url: chainTypesUrls,
            dataOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue()
        )

        let runtimeSyncService = RuntimeSyncService(dataOperationFactory: NetworkOperationFactory())

        let chainRegistry = ChainRegistry(
            runtimeProviderPool: RuntimeProviderPool(),
            connectionPool: ConnectionPool(),
            chainSyncService: chainSyncService,
            chainsTypesSyncService: chainsTypesSyncService,
            runtimeSyncService: runtimeSyncService
        )

        return chainRegistry
    }
}
