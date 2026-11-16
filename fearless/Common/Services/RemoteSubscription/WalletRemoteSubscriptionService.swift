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
    /// The local key each subscription was attached under. It depends on the asset's storage (System.Account,
    /// Tokens.Accounts, Assets.Account…), which a detach cannot derive from the chain asset key alone.
    private var localKeysBySubscription: [String: String] = [:]
    private let localKeysLock = NSLock()

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
                request = MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                    accountId
                }
            default:
                request = NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                    [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: chainAsset.currencyId)]]
                })
            }

            let subscriptionId = attachToSubscription(
                with: [request],
                chainId: chainAsset.chain.chainId,
                cacheKey: localKey,
                queue: queue,
                closure: closure
            ).uuidString

            localKeysLock.lock()
            localKeysBySubscription[subscriptionId] = localKey
            localKeysLock.unlock()

            return subscriptionId
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

        localKeysLock.lock()
        let attachedKey = localKeysBySubscription.removeValue(forKey: subscriptionId)
        localKeysLock.unlock()

        do {
            let localKey = try attachedKey ?? LocalStorageKeyFactory().createFromStoragePath(
                StorageCodingPath.account,
                chainAssetKey: chainAssetKey
            )

            detachFromSubscription(localKey, subscriptionId: uuid, queue: queue, closure: closure)
        } catch {
            callbackClosureIfProvided(closure, queue: queue, result: .failure(error))
        }
    }
}
