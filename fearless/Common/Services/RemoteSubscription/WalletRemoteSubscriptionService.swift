import Foundation

protocol WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainAsset: ChainAsset,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID?

    func detachFromAccountInfo(
        for subscriptionId: UUID,
        chainAssetKey: ChainAssetKey,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

class WalletRemoteSubscriptionService: RemoteSubscriptionService, WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainAsset: ChainAsset,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let storagePath = chainAsset.storagePath

            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
            )

            var request: SubscriptionRequestProtocol

            if chainAsset.chain.isSora, chainAsset.isUtility {
                request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                    accountId
                }
            } else if let currencyId = chainAsset.currencyId {
                request = NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                    [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: currencyId)]]
                })
            } else {
                request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                    accountId
                }
            }

            return attachToSubscription(
                with: [request],
                chainId: chainAsset.chain.chainId,
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
        chainAssetKey: ChainAssetKey,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        do {
            let storagePath = StorageCodingPath.account
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                chainAssetKey: chainAssetKey
            )

            detachFromSubscription(localKey, subscriptionId: subscriptionId, queue: queue, closure: closure)
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
