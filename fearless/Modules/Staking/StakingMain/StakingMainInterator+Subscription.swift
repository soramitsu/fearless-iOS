import Foundation
import RobinHood
import BigInt
import CommonWallet

extension StakingMainInteractor {
    func handle(stashItem: StashItem?) {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(streamableProvider: &controllerAccountProvider)

        if
            let stashItem = stashItem,
            let chainAsset = selectedChainAsset,
            let stashAccountId = try? stashItem.stash.toAccountId(),
            let controllerId = try? stashItem.controller.toAccountId() {
            let chainId = chainAsset.chain.chainId
            ledgerProvider = subscribeLedgerInfo(for: controllerId, chainId: chainId)
            nominatorProvider = subscribeNomination(for: stashAccountId, chainId: chainId)
            validatorProvider = subscribeValidator(for: stashAccountId, chainId: chainId)
            payeeProvider = subscribePayee(for: stashAccountId, chainId: chainId)

            if let rewardApi = chainAsset.chain.externalApi?.staking {
                totalRewardProvider = subscribeTotalReward(
                    for: stashItem.stash,
                    api: rewardApi,
                    assetPrecision: Int16(chainAsset.asset.precision)
                )
            } else {
                let zeroReward = TotalRewardItem(address: stashItem.stash, amount: AmountDecimal(value: 0))
                presenter.didReceive(totalReward: zeroReward)
            }

            subscribeToControllerAccount(address: stashItem.controller, chain: chainAsset.chain)
            fetchAnalyticsRewards(stash: stashItem.stash)
        }

        presenter?.didReceive(stashItem: stashItem)
    }

    func performPriceSubscription() {
        guard let chainAsset = stakingSettings.value else {
            presenter.didReceive(priceError: PersistentValueSettingsError.missingValue)
            return
        }

        guard let priceId = chainAsset.asset.priceId else {
            presenter.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId)
    }

    func performAccountInfoSubscription() {
        guard
            let selectedAccount = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value else {
            presenter.didReceive(balanceError: PersistentValueSettingsError.missingValue)
            return
        }

        guard let accountResponse = selectedAccount.fetch(
            for: chainAsset.chain.accountRequest()
        ) else {
            presenter.didReceive(balanceError: ChainAccountFetchingError.accountNotExists)
            return
        }

        balanceProvider = subscribeToAccountInfoProvider(
            for: accountResponse.accountId,
            chainId: chainAsset.chain.chainId
        )
    }

    func clearStashControllerSubscription() {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(streamableProvider: &stashControllerProvider)
    }

    func performStashControllerSubscription() {
        guard let address = selectedAccount?.toAddress() else {
            presenter.didReceive(stashItemError: ChainAccountFetchingError.accountNotExists)
            return
        }

        stashControllerProvider = subscribeStashItemProvider(for: address)
    }

    func subscribeToControllerAccount(address: AccountAddress, chain: ChainModel) {
        guard controllerAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        let controllerAccountItemProvider = accountProviderFactory.createStreambleProvider(for: accountId)

        controllerAccountProvider = controllerAccountItemProvider

        let updateClosure = { [weak presenter] (changes: [DataProviderChange<MetaAccountModel>]) in
            if
                let controller = changes.reduceToLastChange(),
                let accountItem = try? controller.fetch(for: chain.accountRequest())?.toAccountItem() {
                presenter?.didReceiveControllerAccount(result: .success(accountItem))
            } else {
                presenter?.didReceiveControllerAccount(result: .success(nil))
            }
        }

        let failureClosure = { [weak presenter] (error: Error) in
            presenter?.didReceiveControllerAccount(result: .failure(error))
            return
        }

        let options = StreamableProviderObserverOptions()
        controllerAccountItemProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func clearNominatorsLimitProviders() {
        clear(dataProvider: &minNominatorBondProvider)
        clear(dataProvider: &counterForNominatorsProvider)
        clear(dataProvider: &maxNominatorsCountProvider)
    }

    func performNominatorLimitsSubscripion() {
        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        minNominatorBondProvider = subscribeToMinNominatorBond(for: chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainId)
    }

    private func fetchAnalyticsRewards(stash: AccountAddress) {
        guard let analyticsURL = selectedChainAsset?.chain.externalApi?.staking?.url else { return }

        let period = analyticsPeriod

        let now = Date().timeIntervalSince1970
        let sevenDaysAgo = Date().addingTimeInterval(-(.secondsInDay * 7)).timeIntervalSince1970
        let subqueryRewardsSource = SubqueryRewardsSource(
            address: stash,
            url: analyticsURL,
            startTimestamp: Int64(sevenDaysAgo),
            endTimestamp: Int64(now)
        )
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceieve(subqueryRewards: .success(response), period: period)
                } catch {
                    self?.presenter?.didReceieve(subqueryRewards: .failure(error), period: period)
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension StakingMainInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for address: AccountAddress) {
        guard selectedAccount?.toAddress() == address else {
            return
        }

        switch result {
        case let .success(stashItem):
            handle(stashItem: stashItem)
            presenter.didReceive(stashItem: stashItem)
        case let .failure(error):
            presenter.didReceive(stashItemError: error)
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledgerInfo):
            presenter.didReceive(ledgerInfo: ledgerInfo)
        case let .failure(error):
            presenter.didReceive(ledgerInfoError: error)
        }
    }

    func handleNomination(
        result: Result<Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(nomination):
            presenter.didReceive(nomination: nomination)
        case let .failure(error):
            presenter.didReceive(nominationError: error)
        }
    }

    func handleValidator(
        result: Result<ValidatorPrefs?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(validatorPrefs):
            presenter.didReceive(validatorPrefs: validatorPrefs)
        case let .failure(error):
            presenter.didReceive(validatorError: error)
        }
    }

    func handlePayee(
        result: Result<RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(payee):
            presenter.didReceive(payee: payee)
        case let .failure(error):
            presenter.didReceive(payeeError: error)
        }
    }

    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for address: AccountAddress,
        api _: ChainModel.ExternalApi
    ) {
        guard selectedAccount?.toAddress() == address else {
            return
        }

        switch result {
        case let .success(totalReward):
            presenter.didReceive(totalReward: totalReward)
        case let .failure(error):
            presenter.didReceive(totalReward: error)
        }
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMinNominatorBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter.didReceiveMaxNominatorsCount(result: result)
    }
}

extension StakingMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if let chainAsset = stakingSettings.value, chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter.didReceive(price: priceData)
            case let .failure(error):
                presenter.didReceive(priceError: error)
            }
        }
    }
}

extension StakingMainInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(accountInfo):
            presenter.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            presenter.didReceive(balanceError: error)
        }
    }
}
