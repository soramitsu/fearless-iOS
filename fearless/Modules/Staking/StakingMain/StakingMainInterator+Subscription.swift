import Foundation
import RobinHood
import BigInt

extension StakingMainInteractor {
    func clearPriceProvider() {
        priceProvider?.removeObserver(self)
        priceProvider = nil
    }

    func subscribeToPriceChanges() {
        guard priceProvider == nil, let connection = currentConnection else {
            return
        }

        let asset = primitiveFactory.createAssetForAddressType(connection.type)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            logger.error("Can't create asset id")
            return
        }

        priceProvider = providerFactory.getPriceProvider(for: assetId)

        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(price: nil)
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(price: item)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceError: error)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func clearAccountProvider() {
        balanceProvider?.removeObserver(self)
        balanceProvider = nil
    }

    func subscribeToAccountChanges() {
        guard balanceProvider == nil, let selectedAccount = currentAccount else {
            return
        }

        guard let balanceProvider = try? providerFactory
            .getAccountProvider(
                for: selectedAccount.address,
                runtimeService: runtimeService
            )
        else {
            logger.error("Can't create balance provider")
            return
        }

        self.balanceProvider = balanceProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedAccountInfo>]) in
            let accountInfo = changes.reduceToLastChange()?.item
            self?.presenter.didReceive(accountInfo: accountInfo)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(balanceError: error)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        balanceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func updateAccountAndChainIfNeeded() -> Bool {
        let hasChanges = (currentAccount != settings.selectedAccount) ||
            (currentConnection != settings.selectedConnection)

        if settings.selectedConnection != currentConnection {
            currentConnection = settings.selectedConnection

            clearPriceProvider()
            subscribeToPriceChanges()

            provideNewChain()
        }

        if settings.selectedAccount != currentAccount {
            currentAccount = settings.selectedAccount

            clearAccountProvider()
            subscribeToAccountChanges()

            provideSelectedAccount()
        }

        return hasChanges
    }

    func handle(stashItem: StashItem?) {
        clearLedgerProvider()
        clearNominatorProvider()
        clearValidatorProvider()
        clearTotalRewardProvider()
        clearPayeeProvider()
        clearControllerAccountProvider()

        if let stashItem = stashItem {
            subscribeToLedger(address: stashItem.controller)
            subscribeToNominator(address: stashItem.stash)
            subscribeToValidator(address: stashItem.stash)
            subscribeToTotalReward(address: stashItem.stash)
            subscribeToPayee(address: stashItem.stash)
            subscribeToControllerAccount(address: stashItem.controller)
            fetchAnalyticsRewards(stash: stashItem.stash)
        }

        presenter?.didReceive(stashItem: stashItem)
    }

    func clearStashControllerProvider() {
        clearLedgerProvider()
        clearNominatorProvider()
        clearValidatorProvider()
        clearTotalRewardProvider()
        clearPayeeProvider()

        stashControllerProvider?.removeObserver(self)
        stashControllerProvider = nil
    }

    func subscribeToStashControllerProvider() {
        guard stashControllerProvider == nil, let selectedAccount = currentAccount else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: selectedAccount.address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.handle(stashItem: stashItem)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceive(stashItemError: error)
            return
        }

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )

        stashControllerProvider = provider
    }

    func clearLedgerProvider() {
        ledgerProvider?.removeObserver(self)
        ledgerProvider = nil
    }

    func subscribeToLedger(address: String) {
        guard ledgerProvider == nil else {
            return
        }

        guard let ledgerProvider = try? providerFactory
            .getLedgerInfoProvider(for: address, runtimeService: runtimeService)
        else {
            logger.error("Can't create ledger provider")
            return
        }

        self.ledgerProvider = ledgerProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedLedgerInfo>]) in
            if let ledgerInfo = changes.reduceToLastChange() {
                self?.presenter.didReceive(ledgerInfo: ledgerInfo.item)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(ledgerInfoError: error)
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
    }

    func clearNominatorProvider() {
        nominatorProvider?.removeObserver(self)
        nominatorProvider = nil
    }

    func subscribeToNominator(address: String) {
        guard nominatorProvider == nil else {
            return
        }

        guard let nominatorProvider = try? providerFactory
            .getNominationProvider(for: address, runtimeService: runtimeService)
        else {
            logger.error("Can't create nominator provider")
            return
        }

        self.nominatorProvider = nominatorProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedNomination>]) in
            if let nomination = changes.reduceToLastChange() {
                self?.presenter.didReceive(nomination: nomination.item)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(nominationError: error)
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
    }

    func clearValidatorProvider() {
        validatorProvider?.removeObserver(self)
        validatorProvider = nil
    }

    func subscribeToValidator(address: String) {
        guard validatorProvider == nil else {
            return
        }

        guard let validatorProvider = try? providerFactory
            .getValidatorProvider(for: address, runtimeService: runtimeService)
        else {
            logger.error("Can't create validator provider")
            return
        }

        self.validatorProvider = validatorProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedValidator>]) in
            if let validator = changes.reduceToLastChange() {
                self?.presenter.didReceive(validatorPrefs: validator.item)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(validatorError: error)
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
    }

    func clearTotalRewardProvider() {
        totalRewardProvider?.removeObserver(self)
        totalRewardProvider = nil
    }

    func subscribeToTotalReward(address: String) {
        guard totalRewardProvider == nil, let type = currentConnection?.type else {
            return
        }

        let asset = primitiveFactory.createAssetForAddressType(type)

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            logger.error("Can't create asset id for reward provider")
            return
        }

        guard let totalRewardProvider = try? providerFactory
            .getTotalReward(for: address, assetId: assetId)
        else {
            logger.error("Can't create total reward provider")
            return
        }

        self.totalRewardProvider = totalRewardProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<TotalRewardItem>]) in
            if let totalReward = changes.reduceToLastChange() {
                self?.presenter.didReceive(totalReward: totalReward)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(totalReward: error)
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

        totalRewardProvider.refresh()
    }

    func clearPayeeProvider() {
        payeeProvider?.removeObserver(self)
        payeeProvider = nil
    }

    func clearControllerAccountProvider() {
        controllerAccountProvider?.removeObserver(self)
        controllerAccountProvider = nil
    }

    func subscribeToPayee(address: String) {
        guard payeeProvider == nil else {
            return
        }

        guard let payeeProvider = try? providerFactory
            .getPayee(for: address, runtimeService: runtimeService)
        else {
            logger.error("Can't create payee provider")
            return
        }

        self.payeeProvider = payeeProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedPayee>]) in
            if let payee = changes.reduceToLastChange() {
                self?.presenter.didReceive(payee: payee.item)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(payeeError: error)
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
    }

    func subscribeToControllerAccount(address: AccountAddress) {
        guard controllerAccountProvider == nil else {
            return
        }

        let controllerAccountItemProvider = accountRepositoryFactory.createStreambleProvider(for: address)

        controllerAccountProvider = controllerAccountItemProvider

        let updateClosure = { [weak presenter] (changes: [DataProviderChange<AccountItem>]) in
            let controller = changes.reduceToLastChange()
            presenter?.didReceiveControllerAccount(result: .success(controller))
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

    func subscribeToNominatorsLimit() {
        if let chain = currentConnection?.type.chain {
            minNominatorBondProvider = subscribeToMinNominatorBondProvider(
                chain: chain,
                runtimeService: runtimeService
            )

            counterForNominatorsProvider = subscribeToCounterForNominatorsProvider(
                chain: chain,
                runtimeService: runtimeService
            )

            maxNominatorsCountProvider = subscribeToMaxNominatorsCountProvider(
                chain: chain,
                runtimeService: runtimeService
            )
        }
    }

    private func fetchAnalyticsRewards(stash: AccountAddress) {
        guard let analyticsURL = currentConnection?.type.chain.analyticsURL else { return }
        let period = analyticsPeriod
        let timestampRange = period.timestampInterval(periodDelta: 0)

        let subqueryRewardsSource = SubqueryRewardsSource(
            address: stash,
            url: analyticsURL,
            startTimestamp: timestampRange.0,
            endTimestamp: timestampRange.1
        )
        let fetchOperation = subqueryRewardsSource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    self?.presenter.didReceieve(rewardItemData: .success(response), period: period)
                } catch {
                    self?.presenter.didReceieve(rewardItemData: .failure(error), period: period)
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}

extension StakingMainInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler,
    SubstrateProviderSubscriber, SubstrateProviderSubscriptionHandler,
    AnyProviderAutoCleaning {
    var singleValueProviderFactory: SingleValueProviderFactoryProtocol {
        providerFactory
    }

    func handleMinNominatorBond(result: Result<BigUInt?, Error>, chain _: Chain) {
        presenter.didReceiveMinNominatorBond(result: result)
    }

    func handleCounterForNominators(result: Result<UInt32?, Error>, chain _: Chain) {
        presenter.didReceiveCounterForNominators(result: result)
    }

    func handleMaxNominatorsCount(result: Result<UInt32?, Error>, chain _: Chain) {
        presenter.didReceiveMaxNominatorsCount(result: result)
    }
}
