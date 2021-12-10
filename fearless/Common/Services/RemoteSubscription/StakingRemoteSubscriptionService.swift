import Foundation
import FearlessUtils

protocol StakingRemoteSubscriptionServiceProtocol {
    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

final class StakingRemoteSubscriptionService: RemoteSubscriptionService,
    StakingRemoteSubscriptionServiceProtocol {
    private static let globalDataStoragePaths: [StorageCodingPath] = [
        .activeEra,
        .currentEra,
        .totalIssuance,
        .historyDepth,
        .minNominatorBond,
        .maxNominatorsCount,
        .counterForNominators
    ]

    private static func globalDataParamsCacheKey(for chainId: ChainModel.Id) throws -> String {
        let storageKeyFactory = StorageKeyFactory()
        let cacheKeyData = try globalDataStoragePaths.reduce(Data()) { result, storagePath in
            let storageKeyData = try storageKeyFactory.createStorageKey(
                moduleName: storagePath.moduleName,
                storageName: storagePath.itemName
            )

            return result + storageKeyData
        }

        return try LocalStorageKeyFactory().createKey(from: cacheKeyData, chainId: chainId)
    }

    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let localKeyFactory = LocalStorageKeyFactory()

            let localKeys = try Self.globalDataStoragePaths.map { storagePath in
                try localKeyFactory.createFromStoragePath(
                    storagePath,
                    chainId: chainId
                )
            }

            let cacheKey = try Self.globalDataParamsCacheKey(for: chainId)

            let requests = zip(Self.globalDataStoragePaths, localKeys).map {
                UnkeyedSubscriptionRequest(storagePath: $0.0, localKey: $0.1)
            }

            return attachToSubscription(
                with: requests,
                chainId: chainId,
                cacheKey: cacheKey,
                queue: queue,
                closure: closure
            )
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let cacheKey = try Self.globalDataParamsCacheKey(for: chainId)

            detachFromSubscription(
                cacheKey,
                subscriptionId: subscriptionId,
                queue: queue,
                closure: closure
            )
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
