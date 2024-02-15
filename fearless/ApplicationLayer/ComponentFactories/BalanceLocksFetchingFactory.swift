import Foundation
import SSFModels
import SSFUtils

final class BalanceLocksFetchingFactory {
    static func buildBalanceLocksFetcher(for chainAsset: ChainAsset) throws -> BalanceLocksFetching {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }
        guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let operationManager = OperationManagerFacade.sharedManager
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let storageRequestPerformer = StorageRequestPerformerImpl(
            runtimeService: runtimeService,
            connection: connection,
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory
        )
        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager,
            chainRegistry: chainRegistry
        )
        let crowdloanService = CrowdloanServiceDefault(
            crowdloanOperationFactory: crowdloanOperationFactory,
            runtimeService: runtimeService,
            connection: connection,
            chainAsset: chainAsset,
            operationManager: operationManager
        )

        return BalanceLocksFetchingDefault(
            storageRequestPerformer: storageRequestPerformer,
            chainAsset: chainAsset,
            crowdloanService: crowdloanService
        )
    }
}
