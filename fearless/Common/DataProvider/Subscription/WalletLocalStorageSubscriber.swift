import Foundation
import RobinHood
import BigInt

protocol WalletLocalStorageSubscriber where Self: AnyObject {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol { get }

    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler? { get }

    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ChainStorageItem>?

    func subscribeToOrmlAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ChainStorageItem>?
}

extension WalletLocalStorageSubscriber {
    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ChainStorageItem>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getAccountProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            let finalValue: ChainStorageItem? = changes.reduceToLastChange()
            self?.handleAccountInfo(for: accountId, chainAsset: chainAsset, item: finalValue)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
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
    ) -> StreamableProvider<ChainStorageItem>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getAccountProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            let finalValue: ChainStorageItem? = changes.reduceToLastChange()
            self?.handleOrmlAccountInfo(for: accountId, chainAsset: chainAsset, item: finalValue)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            initialSize: 0,
            refreshWhenEmpty: true
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

    private func handleOrmlAccountInfo(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: ChainStorageItem?
    ) {
        guard let item = item else {
            walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .success(nil),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        guard
            let runtimeCodingService = walletLocalSubscriptionFactory.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<OrmlAccountInfo?>(
            path: .tokens,
            data: item.data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let result = decodingOperation.result else {
                    return
                }

                switch result {
                case let .success(ormlAccountInfo):
                    let accountInfo = AccountInfo(ormlAccountInfo: ormlAccountInfo)
                    self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                        result: .success(accountInfo),
                        accountId: accountId,
                        chainAsset: chainAsset
                    )
                case let .failure(error):
                    self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                        result: .failure(error),
                        accountId: accountId,
                        chainAsset: chainAsset
                    )
                }
            }
        }

        walletLocalSubscriptionFactory.operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func handleAccountInfo(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: ChainStorageItem?
    ) {
        guard let item = item else {
            walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .success(nil),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        guard
            let runtimeCodingService = walletLocalSubscriptionFactory.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<AccountInfo?>(
            path: .account,
            data: item.data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard let result = decodingOperation.result else {
                    return
                }
                self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                    result: result,
                    accountId: accountId,
                    chainAsset: chainAsset
                )
            }
        }

        walletLocalSubscriptionFactory.operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }
}

extension WalletLocalStorageSubscriber where Self: WalletLocalSubscriptionHandler {
    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler? { self }
}
