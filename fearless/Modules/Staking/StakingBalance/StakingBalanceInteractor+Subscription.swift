import RobinHood
import IrohaCrypto

extension StakingBalanceInteractor {
    func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(priceResult: .success(nil))
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(priceResult: .success(item))
                    case .delete:
                        self?.presenter.didReceive(priceResult: .success(nil))
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func subsribeToActiveEra() {
        guard activeEraProvider == nil else { return }

        guard let activeEraProvider = try? providerFactory
            .getActiveEra(for: chain, runtimeService: runtimeCodingService)
        else {
            return
        }

        self.activeEraProvider = activeEraProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedActiveEra>]) in
            if let activeEra = changes.reduceToLastChange() {
                self?.presenter.didReceive(activeEraResult: .success(activeEra.item?.index))
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(activeEraResult: .failure(error))
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
    }

    func subscribeToStashControllerProvider() {
        guard stashControllerProvider == nil else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: accountAddress)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.handle(stashItem: stashItem)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceive(stashItemResult: .failure(error))
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

    func handle(stashItem: StashItem?) {
        if let stashItem = stashItem {
            subscribeToLedger(address: stashItem.controller)
            fetchAccounts(for: stashItem)
        }

        presenter?.didReceive(stashItemResult: .success(stashItem))
    }

    func subscribeToLedger(address: String) {
        guard ledgerProvider == nil else {
            return
        }

        guard let ledgerProvider = try? providerFactory
            .getLedgerInfoProvider(for: address, runtimeService: runtimeCodingService)
        else {
            return
        }

        self.ledgerProvider = ledgerProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedLedgerInfo>]) in
            if let ledgerInfo = changes.reduceToLastChange() {
                self?.presenter.didReceive(ledgerResult: .success(ledgerInfo.item))
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(ledgerResult: .failure(error))
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
}
