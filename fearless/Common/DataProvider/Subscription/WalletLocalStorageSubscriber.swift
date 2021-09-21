import Foundation
import RobinHood

protocol WalletLocalStorageSubscriber where Self: AnyObject {
    var subscriptionFactory: WalletLocalSubscriptionFactoryProtocol { get }

    var subscriptionHandler: WalletLocalSubscriptionHandler { get }

    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedAccountInfo>?
}

extension WalletLocalStorageSubscriber {
    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) -> AnyDataProvider<DecodedAccountInfo>? {
        guard let accountInfoProvider = try? subscriptionFactory.getAccountProvider(
            for: accountId,
            chainId: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            let accountInfo = changes.reduceToLastChange()
            self?.subscriptionHandler.handleAccountInfo(
                result: .success(accountInfo?.item),
                accountId: accountId,
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.subscriptionHandler.handleAccountInfo(
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
}

extension WalletLocalStorageSubscriber where Self: WalletLocalSubscriptionHandler {
    var subscriptionHandler: WalletLocalSubscriptionHandler { self }
}
