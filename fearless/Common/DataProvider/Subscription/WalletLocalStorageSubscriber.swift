import Foundation
import RobinHood
import BigInt

protocol WalletLocalStorageSubscriber where Self: AnyObject {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol { get }

    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler { get }

    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedAccountInfo>?

    func subscribeToOrmlAccountInfoProvider(
        for accountId: AccountId,
        chain: ChainModel
    ) -> AnyDataProvider<DecodedOrmlAccountInfo>?
}

extension WalletLocalStorageSubscriber {
    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedAccountInfo>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getAccountProvider(
            for: accountId,
            chainId: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            let accountInfo = changes.reduceToLastChange()
            self?.walletLocalSubscriptionHandler.handleAccountInfo(
                result: .success(accountInfo?.item),
                accountId: accountId,
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainId: chainId
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
        chain: ChainModel
    ) -> AnyDataProvider<DecodedOrmlAccountInfo>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getOrmlAccountProvider(
            for: accountId,
            chain: chain
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedOrmlAccountInfo>]) in
            guard let ormlAccountInfo = changes.reduceToLastChange()?.item else {
                return
            }

            let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
            self?.walletLocalSubscriptionHandler.handleAccountInfo(
                result: .success(accountInfo),
                accountId: accountId,
                chainId: chain.chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainId: chain.chainId
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
    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler { self }
}
