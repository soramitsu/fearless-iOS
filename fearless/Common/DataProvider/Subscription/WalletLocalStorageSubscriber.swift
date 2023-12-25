import Foundation
import RobinHood
import BigInt
import SSFModels

protocol WalletLocalStorageSubscriber where Self: AnyObject {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol { get }

    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler? { get }

    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<AccountInfoStorageWrapper>?
}

extension WalletLocalStorageSubscriber {
    func subscribeToAccountInfoProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<AccountInfoStorageWrapper>? {
        guard let accountInfoProvider = try? walletLocalSubscriptionFactory.getAccountProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<AccountInfoStorageWrapper>]) in
            let finalValue: AccountInfoStorageWrapper? = changes.reduceToLastChange()
            self?.handleChainStorageItem(for: accountId, chainAsset: chainAsset, item: finalValue)
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
            deliverOn: walletLocalSubscriptionFactory.processingQueue ?? .global(),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return accountInfoProvider
    }

    // MARK: - private methods

    private func handleChainStorageItem(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper?
    ) {
        guard let item = item else {
            walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .success(nil),
                accountId: accountId,
                chainAsset: chainAsset
            )
            return
        }

        if chainAsset.chain.isEthereum {
            handleEthereumAccountInfo(for: accountId, chainAsset: chainAsset, item: item)
            return
        }

        if chainAsset.chain.isSora, chainAsset.isUtility {
            handleAccountInfo(for: accountId, chainAsset: chainAsset, item: item)
            return
        }

        switch chainAsset.chainAssetType {
        case .normal:
            handleAccountInfo(for: accountId, chainAsset: chainAsset, item: item)

        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCrowdloan,
            .vToken,
            .vsToken,
            .stable,
            .assetId,
            .token2,
            .xcm:
            handleOrmlAccountInfo(for: accountId, chainAsset: chainAsset, item: item)
        case .equilibrium:
            handleEquilibrium(for: accountId, chainAsset: chainAsset, item: item)
        case .assets:
            handleAssetAccount(for: accountId, chainAsset: chainAsset, item: item)
        case .soraAsset:
            if chainAsset.isUtility {
                handleAccountInfo(for: accountId, chainAsset: chainAsset, item: item)
            } else {
                handleOrmlAccountInfo(for: accountId, chainAsset: chainAsset, item: item)
            }
        case .none:
            break
        }
    }

    private func handleEthereumAccountInfo(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) {
        do {
            let accountInfo = try JSONDecoder().decode(AccountInfo?.self, from: item.data)
            walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .success(accountInfo),
                accountId: accountId,
                chainAsset: chainAsset
            )
        } catch {
            walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
        }
    }

    private func handleOrmlAccountInfo(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) {
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

        walletLocalSubscriptionFactory.operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func handleAccountInfo(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) {
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
            guard let result = decodingOperation.result else {
                return
            }
            self?.walletLocalSubscriptionHandler?.handleAccountInfo(
                result: result,
                accountId: accountId,
                chainAsset: chainAsset
            )
        }

        walletLocalSubscriptionFactory.operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func handleEquilibrium(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) {
        guard
            let runtimeCodingService = walletLocalSubscriptionFactory.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<EquilibriumAccountInfo?>(
            path: chainAsset.storagePath,
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
            guard let result = decodingOperation.result else {
                return
            }
            self?.handleEquilibrium(result: result, accountId: accountId, chainAsset: chainAsset)
        }

        walletLocalSubscriptionFactory.operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func handleAssetAccount(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        item: AccountInfoStorageWrapper
    ) {
        guard
            let runtimeCodingService = walletLocalSubscriptionFactory.getRuntimeProvider(
                for: chainAsset.chain.chainId
            )
        else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation = StorageDecodingOperation<AssetAccount?>(
            path: .assetsAccount,
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
            guard let result = decodingOperation.result else {
                return
            }

            switch result {
            case let .success(assetAccount):
                let accountInfo = AccountInfo(assetAccount: assetAccount)
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

        walletLocalSubscriptionFactory.operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func handleEquilibrium(
        result: Result<EquilibriumAccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        switch result {
        case let .success(equilibriumAccountInfo):
            switch equilibriumAccountInfo?.data {
            case let .v0data(info):
                let map = info.mapBalances()
                chainAsset.chain.chainAssets.forEach { chainAsset in
                    guard let currencyId = chainAsset.asset.currencyId else {
                        return
                    }
                    let equilibriumFree = map[currencyId]
                    let accountInfo = AccountInfo(equilibriumFree: equilibriumFree)
                    walletLocalSubscriptionHandler?.handleAccountInfo(
                        result: .success(accountInfo),
                        accountId: accountId,
                        chainAsset: chainAsset
                    )
                }
            case .none:
                walletLocalSubscriptionHandler?.handleAccountInfo(
                    result: .success(nil),
                    accountId: accountId,
                    chainAsset: chainAsset
                )
            }
        case let .failure(error):
            walletLocalSubscriptionHandler?.handleAccountInfo(
                result: .failure(error),
                accountId: accountId,
                chainAsset: chainAsset
            )
        }
    }
}

extension WalletLocalStorageSubscriber where Self: WalletLocalSubscriptionHandler {
    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler? { self }
}
