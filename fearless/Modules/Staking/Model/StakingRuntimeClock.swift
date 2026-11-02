import Foundation
import SSFRuntimeCodingService
import SSFUtils

/// Keeps the staking runtime and its relay-chain consensus clock distinct.
protocol StakingRuntimeIdentifying {
    var chainId: String { get }
}

extension RuntimeProvider: StakingRuntimeIdentifying {}

struct StakingRuntimeClock {
    let runtime: (String) -> RuntimeCodingServiceProtocol?
    let connection: (String) -> JSONRPCEngine?

    init(
        runtime: @escaping (String) -> RuntimeCodingServiceProtocol? = {
            ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: $0)
        },
        connection: @escaping (String) -> JSONRPCEngine? = {
            ChainRegistryFacade.sharedRegistry.getConnection(for: $0)
        }
    ) {
        self.runtime = runtime
        self.connection = connection
    }

    func route(for stakingRuntime: RuntimeCodingServiceProtocol) -> AssetHubStakingRoute? {
        guard let identity = stakingRuntime as? StakingRuntimeIdentifying else { return nil }
        return AssetHubStakingRoute.staking(on: identity.chainId)
    }

    func runtime(for stakingRuntime: RuntimeCodingServiceProtocol) throws -> RuntimeCodingServiceProtocol {
        guard let route = route(for: stakingRuntime) else { return stakingRuntime }
        guard let relay = runtime(route.relayChainId) else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }
        return relay
    }

    func connection(
        for stakingRuntime: RuntimeCodingServiceProtocol,
        stakingConnection: JSONRPCEngine
    ) throws -> JSONRPCEngine {
        guard let route = route(for: stakingRuntime) else { return stakingConnection }
        guard let relay = connection(route.relayChainId) else {
            throw ChainRegistryError.connectionUnavailable
        }
        return relay
    }
}
