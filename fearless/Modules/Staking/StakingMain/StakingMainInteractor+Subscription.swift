import Foundation
import RobinHood
import BigInt
import CommonWallet
import FearlessUtils

extension StakingMainInteractor {
    func handle(stashItem: StashItem?) {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(singleValueProvider: &rewardAnalyticsProvider)
        clear(streamableProvider: &controllerAccountProvider)

        if
            let stashItem = stashItem,
            let chainAsset = selectedChainAsset,
            let stashAccountId = try? AddressFactory.accountId(from: stashItem.stash, chain: chainAsset.chain),
            let controllerId = try? AddressFactory.accountId(from: stashItem.controller, chain: chainAsset.chain) {
            ledgerProvider = subscribeLedgerInfo(for: controllerId, chainAsset: chainAsset)
            nominatorProvider = subscribeNomination(for: stashAccountId, chainAsset: chainAsset)
            validatorProvider = subscribeValidator(for: stashAccountId, chainAsset: chainAsset)
            payeeProvider = subscribePayee(for: stashAccountId, chainAsset: chainAsset)

            if let _ = chainAsset.chain.externalApi?.staking {
                totalRewardProvider = subscribeTotalReward(
                    for: stashItem.stash,
                    chain: chainAsset.chain,
                    assetPrecision: Int16(chainAsset.asset.precision)
                )
            } else {
                let zeroReward = TotalRewardItem(address: stashItem.stash, amount: AmountDecimal(value: 0))
                presenter?.didReceive(totalReward: zeroReward)
            }

            subscribeToControllerAccount(address: stashItem.controller, chain: chainAsset.chain)
            subscribeRewardsAnalytics(for: stashItem.stash)
        }

        presenter?.didReceive(stashItem: stashItem)
    }

    func performPriceSubscription() {
        guard let chainAsset = stakingSettings.value else {
            presenter?.didReceive(priceError: PersistentValueSettingsError.missingValue)
            return
        }

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId)
    }

    func performAccountInfoSubscription() {
        guard
            let selectedAccount = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value else {
            presenter?.didReceive(balanceError: PersistentValueSettingsError.missingValue)
            return
        }

        guard let accountResponse = selectedAccount.fetch(
            for: chainAsset.chain.accountRequest()
        ) else {
            presenter?.didReceive(balanceError: ChainAccountFetchingError.accountNotExists)
            return
        }

        accountInfoSubscriptionAdapter.subscribe(
            chainAsset: chainAsset,
            accountId: accountResponse.accountId,
            handler: self
        )
    }

    func clearStashControllerSubscription() {
        clear(dataProvider: &ledgerProvider)
        clear(dataProvider: &nominatorProvider)
        clear(dataProvider: &validatorProvider)
        clear(singleValueProvider: &totalRewardProvider)
        clear(dataProvider: &payeeProvider)
        clear(singleValueProvider: &rewardAnalyticsProvider)
        clear(streamableProvider: &stashControllerProvider)
    }

    func performStashControllerSubscription() {
        guard selectedChainAsset?.stakingType?.isRelaychain == true else {
            return
        }

        guard let address = selectedAccount?.toAddress() else {
            presenter?.didReceive(stashItemError: ChainAccountFetchingError.accountNotExists)
            return
        }

        stashControllerProvider = subscribeStashItemProvider(for: address)
    }

    func subscribeToControllerAccount(address: AccountAddress, chain: ChainModel) {
        guard controllerAccountProvider == nil, let accountId = try? AddressFactory.accountId(from: address, chain: chain) else {
            return
        }

        let controllerAccountItemProvider = accountProviderFactory.createStreambleProvider(for: accountId)

        controllerAccountProvider = controllerAccountItemProvider

        let updateClosure = { [weak presenter] (changes: [DataProviderChange<MetaAccountModel>]) in
            if
                let controller = changes.reduceToLastChange(),
                let accountItem = controller.fetch(for: chain.accountRequest()) {
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
        guard selectedChainAsset?.stakingType?.isRelaychain == true else {
            return
        }

        guard let chainId = selectedChainAsset?.chain.chainId else {
            return
        }

        minNominatorBondProvider = subscribeToMinNominatorBond(for: chainId)
        counterForNominatorsProvider = subscribeToCounterForNominators(for: chainId)
        maxNominatorsCountProvider = subscribeMaxNominatorsCount(for: chainId)
    }

    func subscribeRewardsAnalytics(for address: AccountAddress) {
        if let analyticsURL = selectedChainAsset?.chain.externalApi?.staking?.url,
           selectedChainAsset?.stakingType?.isParachain == true,
           let chainAsset = selectedChainAsset {
            rewardAnalyticsProvider = subscribeWeaklyRewardAnalytics(chainAsset: chainAsset, for: address, url: analyticsURL)
        } else {
            presenter?.didReceieve(
                subqueryRewards: .success(nil),
                period: .week
            )
        }
    }
}

extension StakingMainInteractor: ParachainStakingLocalStorageSubscriber, ParachainStakingLocalSubscriptionHandler {
    func handleDelegatorState(
        result: Result<ParachainStakingDelegatorState?, Error>,
        chainAsset: ChainAsset,
        accountId _: AccountId
    ) {
        guard
            chainAsset == selectedChainAsset else {
            return
        }
        switch result {
        case let .success(delegatorState):
            handleDelegatorState(delegatorState: delegatorState, chainAsset: chainAsset)
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }

    func handleDelegationScheduledRequests(
        result _: Result<[ParachainStakingScheduledRequest]?, Error>,
        chainAsset _: ChainAsset,
        accountId _: AccountId
    ) {
        guard let collatorIds = collatorIds else {
            return
        }
        fetchCollatorsDelegations(accountIds: collatorIds)
    }
}

extension StakingMainInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for address: AccountAddress) {
        guard selectedAccount?.toAddress() == address else {
            return
        }

        switch result {
        case let .success(stashItem):
            handle(stashItem: stashItem)
            presenter?.didReceive(stashItem: stashItem)
        case let .failure(error):
            presenter?.didReceive(stashItemError: error)
        }
    }

    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledgerInfo):
            presenter?.didReceive(ledgerInfo: ledgerInfo)
        case let .failure(error):
            presenter?.didReceive(ledgerInfoError: error)
        }
    }

    func handleNomination(
        result: Result<Nomination?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(nomination):
            presenter?.didReceive(nomination: nomination)
        case let .failure(error):
            presenter?.didReceive(nominationError: error)
        }
    }

    func handleValidator(
        result: Result<ValidatorPrefs?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(validatorPrefs):
            presenter?.didReceive(validatorPrefs: validatorPrefs)
        case let .failure(error):
            presenter?.didReceive(validatorError: error)
        }
    }

    func handlePayee(
        result: Result<RewardDestinationArg?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(payee):
            presenter?.didReceive(payee: payee)
        case let .failure(error):
            presenter?.didReceive(payeeError: error)
        }
    }

    func handleTotalReward(
        result: Result<TotalRewardItem, Error>,
        for _: AccountAddress,
        api _: ChainModel.BlockExplorer
    ) {
        switch result {
        case let .success(totalReward):
            presenter?.didReceive(totalReward: totalReward)
        case let .failure(error):
            presenter?.didReceive(totalReward: error)
        }
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveMinNominatorBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chainId _: ChainModel.Id) {
        presenter?.didReceiveMaxNominatorsCount(result: result)
    }
}

extension StakingMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if let chainAsset = stakingSettings.value, chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                guard let priceData = priceData else { return }
                presenter?.didReceive(price: priceData)
            case let .failure(error):
                presenter?.didReceive(priceError: error)
            }
        }

        if let chainAsset = rewardChainAsset, chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                guard let priceData = priceData else { return }
                presenter?.didReceive(rewardAssetPrice: priceData)
            case let .failure(error):
                presenter?.didReceive(priceError: error)
            }
        }
    }
}

extension StakingMainInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        switch result {
        case let .success(accountInfo):
            presenter?.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            presenter?.didReceive(balanceError: error)
        }
    }
}

extension StakingMainInteractor: StakingAnalyticsLocalStorageSubscriber,
    StakingAnalyticsLocalSubscriptionHandler {
    func handleWeaklyRewardAnalytics(
        result: Result<[SubqueryRewardItemData]?, Error>,
        address: AccountAddress,
        url _: URL
    ) {
        guard selectedAccount?.toAddress()?.lowercased() == address.lowercased() else {
            return
        }

        presenter?.didReceieve(subqueryRewards: result, period: .week)
    }
}
