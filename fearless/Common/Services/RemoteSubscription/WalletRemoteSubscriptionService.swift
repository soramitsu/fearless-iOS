import Foundation

protocol WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAccountInfo(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

class WalletRemoteSubscriptionService: RemoteSubscriptionService, WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let storagePath = StorageCodingPath.account
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chainId
            )

            let request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) { accountId }

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

    func detachFromAccountInfo(
        for subscriptionId: UUID,
        accountId: AccountId,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storagePath = StorageCodingPath.account
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chainId
            )

            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
