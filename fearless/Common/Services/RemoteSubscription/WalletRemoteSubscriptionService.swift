import Foundation
import SSFModels

protocol WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        wallet: MetaAccountModel,
        chainModel: ChainModel,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) async -> String?

    func detachFromAccountInfo(
        for subscriptionId: String,
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    )
}

class WalletRemoteSubscriptionService: RemoteSubscriptionService<AccountInfoStorageWrapper>, WalletRemoteSubscriptionServiceProtocol {
    func attachToAccountInfo(
        wallet: MetaAccountModel,
        chainModel: ChainModel,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) async -> String? {
        do {
            let requests: [SubscriptionRequestProtocol] = try chainModel.chainAssets.compactMap { chainAsset in
                guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                    return nil
                }
                let storagePath = chainAsset.storagePath

                let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                    storagePath,
                    chainAssetKey: chainAsset.uniqueKey(accountId: accountId)
                )

                switch chainAsset.currencyId {
                case .soraAsset:
                    if chainAsset.isUtility {
                        return MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                            accountId
                        }
                    } else {
                        return NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                            [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: chainAsset.currencyId)]]
                        })
                    }
                case .equilibrium:
                    return MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                        accountId
                    }
                case .assets:
                    return NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                        [[NMapKeyParam(value: chainAsset.currencyId)], [NMapKeyParam(value: accountId)]]
                    })
                case .none:
                    return MapSubscriptionRequest(storagePath: storagePath, localKey: localKey) {
                        accountId
                    }
                default:
                    return NMapSubscriptionRequest(storagePath: storagePath, localKey: localKey, keyParamClosure: {
                        [[NMapKeyParam(value: accountId)], [NMapKeyParam(value: chainAsset.currencyId)]]
                    })
                }
            }

            return attachToSubscription(
                with: requests,
                chainId: chainModel.chainId,
                cacheKey: chainModel.chainId,
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
        chainId: ChainModel.Id,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        detachFromSubscription(chainId, subscriptionId: subscriptionId, queue: queue, closure: closure)
    }
}
