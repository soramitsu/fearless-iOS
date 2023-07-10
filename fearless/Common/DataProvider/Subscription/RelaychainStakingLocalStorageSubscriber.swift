import Foundation
import RobinHood
import SSFModels

protocol RelaychainStakingLocalStorageSubscriber where Self: AnyObject {
    var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol { get }

    var stakingLocalSubscriptionHandler: RelaychainStakingLocalSubscriptionHandler { get }

    func subscribeToMinNominatorBond(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedBigUInt>?

    func subscribeToCounterForNominators(for chainId: ChainModel.Id)
        -> AnyDataProvider<DecodedU32>?

    func subscribeMaxNominatorsCount(for chainId: ChainModel.Id)
        -> AnyDataProvider<DecodedU32>?

    func subscribeNomination(for accountId: AccountId, chainAsset: ChainAsset)
        -> AnyDataProvider<DecodedNomination>?

    func subscribeValidator(for accountId: AccountId, chainAsset: ChainAsset)
        -> AnyDataProvider<DecodedValidator>?

    func subscribeLedgerInfo(for accountId: AccountId, chainAsset: ChainAsset)
        -> AnyDataProvider<DecodedLedgerInfo>?

    func subscribeActiveEra(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedActiveEra>?

    func subscribeCurrentEra(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedEraIndex>?

    func subscribePayee(for accountId: AccountId, chainAsset: ChainAsset) -> AnyDataProvider<DecodedPayee>?

    func subscribeTotalReward(
        for address: AccountAddress,
        chain: ChainModel,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>?

    func subscribeStashItemProvider(
        for address: AccountAddress
    ) -> StreamableProvider<StashItem>?

    func subscribeToPoolMembers(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedPoolMember>?
}

extension RelaychainStakingLocalStorageSubscriber {
    func subscribeToMinNominatorBond(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedBigUInt>? {
        guard let minBondProvider = try? stakingLocalSubscriptionFactory.getMinNominatorBondProvider(
            for: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedBigUInt>]) in
            let minNominatorBond = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleMinNominatorBond(
                result: .success(minNominatorBond?.item?.value),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleMinNominatorBond(
                result: .failure(error),
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        minBondProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return minBondProvider
    }

    func subscribeToCounterForNominators(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let counterForNominatorProvider = try? stakingLocalSubscriptionFactory
            .getCounterForNominatorsProvider(for: chainId) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedU32>]) in
            let counterForNominators = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleCounterForNominators(
                result: .success(counterForNominators?.item?.value),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleCounterForNominators(
                result: .failure(error),
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        counterForNominatorProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return counterForNominatorProvider
    }

    func subscribeMaxNominatorsCount(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedU32>? {
        guard let maxNominatorsCountProvider = try? stakingLocalSubscriptionFactory
            .getMaxNominatorsCountProvider(for: chainId) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedU32>]) in
            let maxNominatorsCount = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleMaxNominatorsCount(
                result: .success(maxNominatorsCount?.item?.value),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleMaxNominatorsCount(
                result: .failure(error),
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        maxNominatorsCountProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return maxNominatorsCountProvider
    }

    func subscribeNomination(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedNomination>? {
        guard let nominatorProvider = try? stakingLocalSubscriptionFactory.getNominationProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedNomination>]) in
            let nomination = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleNomination(
                result: .success(nomination?.item),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleNomination(
                result: .failure(error),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        nominatorProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return nominatorProvider
    }

    func subscribeValidator(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedValidator>? {
        guard let validatorProvider = try? stakingLocalSubscriptionFactory.getValidatorProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedValidator>]) in
            let validator = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleValidator(
                result: .success(validator?.item),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleValidator(
                result: .failure(error),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        validatorProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return validatorProvider
    }

    func subscribeLedgerInfo(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedLedgerInfo>? {
        guard let ledgerProvider = try? stakingLocalSubscriptionFactory.getLedgerInfoProvider(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedLedgerInfo>]) in
            let ledgerInfo = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleLedgerInfo(
                result: .success(ledgerInfo?.item),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleLedgerInfo(
                result: .failure(error),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        ledgerProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return ledgerProvider
    }

    func subscribeActiveEra(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedActiveEra>? {
        guard let activeEraProvider = try? stakingLocalSubscriptionFactory.getActiveEra(
            for: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedActiveEra>]) in
            let activeEra = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleActiveEra(
                result: .success(activeEra?.item),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleActiveEra(
                result: .failure(error),
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        activeEraProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return activeEraProvider
    }

    func subscribeCurrentEra(for chainId: ChainModel.Id) -> AnyDataProvider<DecodedEraIndex>? {
        guard let currentEraProvider = try? stakingLocalSubscriptionFactory.getCurrentEra(
            for: chainId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedEraIndex>]) in
            let currentEra = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleCurrentEra(
                result: .success(currentEra?.item?.value),
                chainId: chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleCurrentEra(
                result: .failure(error),
                chainId: chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        currentEraProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return currentEraProvider
    }

    func subscribePayee(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedPayee>? {
        guard let payeeProvider = try? stakingLocalSubscriptionFactory.getPayee(
            for: accountId,
            chainAsset: chainAsset
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedPayee>]) in
            let payee = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handlePayee(
                result: .success(payee?.item),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handlePayee(
                result: .failure(error),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        payeeProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return payeeProvider
    }

    func subscribeTotalReward(
        for address: AccountAddress,
        chain: ChainModel,
        assetPrecision: Int16
    ) -> AnySingleValueProvider<TotalRewardItem>? {
        guard let api = chain.externalApi?.staking,
              let totalRewardProvider = try? stakingLocalSubscriptionFactory.getTotalReward(
                  for: address,
                  chain: chain,
                  assetPrecision: assetPrecision
              ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<TotalRewardItem>]) in
            if let finalValue = changes.reduceToLastChange() {
                self?.stakingLocalSubscriptionHandler.handleTotalReward(
                    result: .success(finalValue),
                    for: address,
                    api: api
                )
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handleTotalReward(
                result: .failure(error),
                for: address,
                api: api
            )

            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: true,
            waitsInProgressSyncOnAdd: false
        )

        totalRewardProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return totalRewardProvider
    }

    func subscribeStashItemProvider(
        for address: AccountAddress
    ) -> StreamableProvider<StashItem>? {
        let provider = stakingLocalSubscriptionFactory.getStashItemProvider(for: address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handleStashItem(
                result: .success(stashItem),
                for: address
            )
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.stakingLocalSubscriptionHandler.handleStashItem(
                result: .failure(error),
                for: address
            )
            return
        }

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )

        return provider
    }

    func subscribeToPoolMembers(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> AnyDataProvider<DecodedPoolMember>? {
        guard let poolMembersProvider = try? stakingLocalSubscriptionFactory.getPoolMembersProvider(
            for: chainAsset,
            accountId: accountId
        ) else {
            return nil
        }

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedPoolMember>]) in
            let poolMember = changes.reduceToLastChange()
            self?.stakingLocalSubscriptionHandler.handlePoolMember(
                result: .success(poolMember?.item),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingLocalSubscriptionHandler.handlePoolMember(
                result: .failure(error),
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        poolMembersProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return poolMembersProvider
    }
}

extension RelaychainStakingLocalStorageSubscriber where Self: RelaychainStakingLocalSubscriptionHandler {
    var stakingLocalSubscriptionHandler: RelaychainStakingLocalSubscriptionHandler { self }
}
