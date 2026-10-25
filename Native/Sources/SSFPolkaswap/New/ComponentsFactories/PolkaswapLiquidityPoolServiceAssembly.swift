import Foundation
import SSFModels
import SSFStorageQueryKit
import SSFChainRegistry
import sorawallet
import SSFRuntimeCodingService

public final class PolkaswapLiquidityPoolServiceAssembly {
    public static func buildService(for chain: ChainModel, chainRegistry: ChainRegistryProtocol) -> PolkaswapLiquidityPoolService {
        let storageRequestPerformer = StorageRequestPerformerDefault(chainRegistry: chainRegistry)
        let dexManagerStorage = DexManagerStorageDefault(storageRequestPerformer: storageRequestPerformer)
        let poolXykStorage = PoolXykStorageDefaultL(storageRequestPerformer: storageRequestPerformer)
        let httpProvider = SoramitsuHttpClientProviderImpl()
        let soraNetworkClient = SoramitsuNetworkClient(
            timeout: 60000,
            logging: true,
            provider: httpProvider
        )
        let configProvider = SoraRemoteConfigProvider(client: soraNetworkClient, commonUrl: "https://config.polkaswap2.io/prod/common.json", mobileUrl: "https://config.polkaswap2.io/stage/mobile.json")
        let builder = configProvider.provide()
        let apyWorker = PolkaswapAPYWorkerDefault(
            networkClient: soraNetworkClient,
            configBuilder: builder
        )
        
        return PolkaswapLiquidityPoolServiceDefault(
            dexManagerStorage: dexManagerStorage,
            poolXykStorage: poolXykStorage,
            chain: chain,
            apyWorker: apyWorker
        )
    }
}
