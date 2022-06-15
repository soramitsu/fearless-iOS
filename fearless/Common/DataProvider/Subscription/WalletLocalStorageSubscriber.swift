import Foundation
import RobinHood
import BigInt

protocol WalletLocalStorageSubscriber where Self: AnyObject {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol { get }

    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler? { get }

    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedAccountInfo>?

    func subscribeToOrmlAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedOrmlAccountInfo>?
}

extension WalletLocalStorageSubscriber {
    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedAccountInfo>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getAccountProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            guard !changes.isEmpty else { return }
            let accountInfo = changes.reduceToLastChange()?.item
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .success(accountInfo),
                accountId: accountId,
                chainAsset: chainAsset
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        accountInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return accountInfoProvider
    }

    func subscribeToOrmlAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedOrmlAccountInfo>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getOrmlAccountProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedOrmlAccountInfo>]) in
            guard !changes.isEmpty else { return }
            let ormlAccountInfo = changes.reduceToLastChange()?.item

            let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .success(accountInfo),
                accountId: accountId,
                chainAsset: chainAsset
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        accountInfoProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return accountInfoProvider
    }
}

extension WalletLocalStorageSubscriber where Self: WalletLocalSubscriptionHandler {
    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler? { self }
}
