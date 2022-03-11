import Foundation

protocol WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chain: ChainModel,
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
        chain: ChainModel,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID? {
        do {
            let storagePath = chain.chainId.isOrml ? StorageCodingPath.tokens : StorageCodingPath.account

            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chain.chainId,
                tokenSymbol: chain.tokenSymbol
            )

            var request: SubscriptionRequestProtocol

            if let tokenSymbol = chain.tokenSymbol {
                let data = CurrencyId.token(symbol: tokenSymbol)

                request = NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                    [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: data)]]
                })
            } else {
                request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                    accountId
                }
            }

            return attachToSubscription(
                with: [request],
                chainId: chain.chainId,
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
