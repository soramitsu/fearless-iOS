import Foundation

// TODO: Will be implemented in FLW-1192

protocol RuntimeProviderProtocol {}

final class RuntimeProvider {
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let chainId: ChainModel.Id

    init(runtimeSyncService: RuntimeSyncServiceProtocol, chainModel: ChainModel) {
        self.runtimeSyncService = runtimeSyncService
        chainId = chainModel.chainId
    }
}

extension RuntimeProvider: RuntimeProviderProtocol {}
