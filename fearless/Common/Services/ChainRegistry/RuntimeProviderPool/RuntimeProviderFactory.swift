import Foundation

protocol RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol
}

final class RuntimeProviderFactory {
    let runtimeSyncService: RuntimeSyncServiceProtocol

    init(runtimeSyncService: RuntimeSyncServiceProtocol) {
        self.runtimeSyncService = runtimeSyncService
    }
}

extension RuntimeProviderFactory: RuntimeProviderFactoryProtocol {
    func createRuntimeProvider(for chain: ChainModel) -> RuntimeProviderProtocol {
        RuntimeProvider(runtimeSyncService: runtimeSyncService, chainModel: chain)
    }
}
