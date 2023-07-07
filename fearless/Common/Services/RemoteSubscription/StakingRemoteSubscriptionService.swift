import Foundation
import SSFUtils
import SSFModels

protocol StakingRemoteSubscriptionServiceProtocol {
    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        stakingType: StakingType?
    ) -> UUID?

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        stakingType: StakingType?
    )
}

final class StakingRemoteSubscriptionService: RemoteSubscriptionService<ChainStorageItem>,
    StakingRemoteSubscriptionServiceProtocol {
    private static func globalDataStoragePaths(stakingType: StakingType?) -> [StorageCodingPath] {
        switch stakingType {
        case .relaychain, .sora, .ternoa:
            return [
                .activeEra,
                .currentEra,
                .totalIssuance,
                .minNominatorBond,
                .maxNominatorsCount,
                .counterForNominators
            ]
        case .parachain:
            return [.totalIssuance]
        case .none:
            return []
        }
    }

    private static func globalDataParamsCacheKey(
        for chainId: ChainModel.Id,
        stakingType: StakingType?
    ) throws -> String {
        let storageKeyFactory = StorageKeyFactory()
        let cacheKeyData = try globalDataStoragePaths(stakingType: stakingType).reduce(Data()) { result, storagePath in
            let storageKeyData = try storageKeyFactory.createStorageKey(
                moduleName: storagePath.moduleName,
                storageName: storagePath.itemName
            )

            return result + storageKeyData
        }

        return try LocalStorageKeyFactory().createKey(from: cacheKeyData, key: chainId)
    }

//    add parachain case
    func attachToGlobalData(
        for chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?,
        stakingType: StakingType?
    ) -> UUID? {
        do {
            print("Creating localKeyFactory")
            let localKeyFactory = LocalStorageKeyFactory()

            //   RelaychainKeys + ParachainKeys - All ParachainStakingKeys
            print("Creating localKeys")
            let localKeys = try Self.globalDataStoragePaths(stakingType: stakingType).map { storagePath in
                try localKeyFactory.createFromStoragePath(
                    storagePath,
                    chainId: chainId
                )
            }

            print("Creating cacheKey")
            let cacheKey = try Self.globalDataParamsCacheKey(for: chainId, stakingType: stakingType)

            print("Creating requests")
            let requests = zip(Self.globalDataStoragePaths(stakingType: stakingType), localKeys).map {
                UnkeyedSubscriptionRequest(storagePath: $0.0, localKey: $0.1)
            }

            print("Start attachToSubscription")
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
        closure: RemoteSubscriptionClosure?,
        stakingType: StakingType?
    ) {
        do {
            let cacheKey = try Self.globalDataParamsCacheKey(for: chainId, stakingType: stakingType)

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
