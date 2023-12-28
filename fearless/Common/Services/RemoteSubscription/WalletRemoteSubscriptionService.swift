import Foundation
import SSFModels

protocol WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainAsset: ChainAsset,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) async -> String?

    func detachFromAccountInfo(
        for subscriptionId: String,
        chainAssetKey: ChainAssetKey,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

class WalletRemoteSubscriptionService: RemoteSubscriptionService<AccountInfoStorageWrapper>, WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        of accountId: AccountId,
        chainAsset: ChainAsset,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) async -> String? {
        do {
            let storagePath = chainAsset.storagePath

            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
            )

            var request: SubscriptionRequestProtocol

            switch chainAsset.currencyId {
            case .soraAsset:
                if chainAsset.isUtility {
                    request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                        accountId
                    }
                } else {
                    request = NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                        [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: chainAsset.currencyId)]]
                    })
                }
            case .equilibrium:
                request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                    accountId
                }
            case .assets:
                request = NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                    [[NMapKeyParam(value: chainAsset.currencyId)], [NMapKeyParam(value: accountId)]]
                })
            case .none:
                if chainAsset.chain.chainId == Chain.reef.genesisHash || chainAsset.chain.chainId == Chain.scuba.genesisHash {
                    request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                        accountId.toHexString()
                    }
                } else {
                    request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                        accountId
                    }
                }
            default:
                request = NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                    [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: chainAsset.currencyId)]]
                })
            }

            return attachToSubscription(
                with: [request],
                chainId: chainAsset.chain.chainId,
                cacheKey: localKey,
                queue: queue,
                closure: closure
            ).uuidString
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
            return nil
        }
    }

    func detachFromAccountInfo(
        for subscriptionId: String,
        chainAssetKey: ChainAssetKey,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        guard let uuid = UUID(uuidString: subscriptionId) else {
            return
        }

        do {
            let storagePath = StorageCodingPath.account
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                storagePath,
                chainAssetKey: chainAssetKey
            )

            detachFromSubscription(localKey, subscriptionId: uuid, queue: queue, closure: closure)
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
