import Foundation
import SSFStorageQueryKit
import SSFModels

public enum DexManagerStorageError: Error {
    case dexInfosNotFound
}

public typealias DexInfoByDexId = [String: DexInfos]

public protocol DexManagerStorage {
    func dexInfos(chain: ChainModel) async throws -> DexInfoByDexId
    func subscribeDexInfos(chain: ChainModel) async throws -> AsyncThrowingStream<CachedStorageResponse<DexInfoByDexId>, Error>
}

public final class DexManagerStorageDefault: DexManagerStorage {
    private let storageRequestPerformer: StorageRequestPerformer
    
    init(storageRequestPerformer: StorageRequestPerformer) {
        self.storageRequestPerformer = storageRequestPerformer
    }

    public func dexInfos(chain: ChainModel) async throws -> DexInfoByDexId {
        let baseAssetIdsRequest = DexManagerDexInfosStorageRequest()
        let dexInfos: DexInfoByDexId? = try await storageRequestPerformer.performPrefix(baseAssetIdsRequest, chain: chain)
        
        guard let dexInfos else {
            throw DexManagerStorageError.dexInfosNotFound
        }
        
        return dexInfos
    }

    public func subscribeDexInfos(chain: ChainModel) async throws -> AsyncThrowingStream<CachedStorageResponse<DexInfoByDexId>, Error> {
        let baseAssetIdsRequest = DexManagerDexInfosStorageRequest()
        let dexInfos: AsyncThrowingStream<CachedStorageResponse<DexInfoByDexId>, Error> = await storageRequestPerformer.performPrefix(baseAssetIdsRequest, withCacheOptions: .onAll, chain: chain)
        return dexInfos
    }
}
