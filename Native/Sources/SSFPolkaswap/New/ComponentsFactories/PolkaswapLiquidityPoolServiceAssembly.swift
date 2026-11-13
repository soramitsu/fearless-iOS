import Foundation
import SSFModels
import SSFStorageQueryKit
import SSFChainRegistry
import SSFRuntimeCodingService

public final class PolkaswapLiquidityPoolServiceAssembly {
    public static func buildService(
        for chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        apyIndexerURL: URL = PolkaswapAPYWorkerDefault.soraIndexerURL
    ) -> PolkaswapLiquidityPoolService {
        let storageRequestPerformer = StorageRequestPerformerDefault(chainRegistry: chainRegistry)
        let dexManagerStorage = DexManagerStorageDefault(storageRequestPerformer: storageRequestPerformer)
        let poolXykStorage = PoolXykStorageDefaultL(storageRequestPerformer: storageRequestPerformer)
        let apyWorker = PolkaswapAPYWorkerDefault(endpoint: apyIndexerURL)

        return PolkaswapLiquidityPoolServiceDefault(
            dexManagerStorage: dexManagerStorage,
            poolXykStorage: poolXykStorage,
            chain: chain,
            apyWorker: apyWorker
        )
    }
}
