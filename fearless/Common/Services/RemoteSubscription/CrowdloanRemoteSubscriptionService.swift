import Foundation

protocol CrowdloanRemoteSubscriptionServiceProtocol {
    func attach(
        for chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detach(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    )
}

extension CrowdloanRemoteSubscriptionServiceProtocol {
    func attach(for chainId: ChainModel.Id) -> UUID? {
        attach(for: chainId, runningCompletionIn: nil, completion: nil)
    }

    func detach(
        for subscriptionId: UUID,
        chainId: ChainModel.Id
    ) {
        detach(for: subscriptionId, chainId: chainId, runningCompletionIn: nil, completion: nil)
    }
}

class CrowdloanRemoteSubscriptionService: RemoteSubscriptionService, CrowdloanRemoteSubscriptionServiceProtocol {
    func attach(
        for chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let storagePath = StorageCodingPath.blockNumber
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(storagePath, chainId: chainId)

            let request = UnkeyedSubscriptionRequest(storagePath: storagePath, localKey: localKey)

            return attachToSubscription(
                with: [request],
                chainId: chainId,
                cacheKey: localKey,
                queue: queue,
                closure: closure
            )

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detach(
        for subscriptionId: UUID,
        chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storagePath = StorageCodingPath.blockNumber
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(storagePath, chainId: chainId)

            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)

        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
