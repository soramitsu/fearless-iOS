import Foundation
import RobinHood

extension YourValidatorsInteractor {
    func clearAllSubscriptions() {
        clearActiveEraSubscription()
        clearStashControllerProvider()
        clearNominatorProvider()
    }

    func clearActiveEraSubscription() {
        activeEraProvider?.removeObserver(self)
        activeEraProvider = nil
    }

    func subscribeToActiveEraProvider() {
        guard activeEraProvider == nil else {
            return
        }

        do {
            let provider = try providerFactory.getActiveEra(for: chain, runtimeService: runtimeService)

            let changesClosure: ([DataProviderChange<DecodedActiveEra>]) -> Void = { [weak self] changes in
                let activeEra = changes.reduceToLastChange()
                self?.handle(activeEra: activeEra?.item?.index)
            }

            let failureClosure: (Error) -> Void = { [weak self] error in
                self?.presenter.didReceiveValidators(result: .failure(error))
                return
            }

            let options = DataProviderObserverOptions(
                alwaysNotifyOnRefresh: false,
                waitsInProgressSyncOnAdd: false
            )

            provider.addObserver(
                self,
                deliverOn: .main,
                executing: changesClosure,
                failing: failureClosure,
                options: options
            )

            activeEraProvider = provider
        } catch {
            presenter.didReceiveController(result: .failure(error))
            presenter.didReceiveValidators(result: .failure(error))
        }
    }

    func clearStashControllerProvider() {
        stashControllerProvider?.removeObserver(self)
        stashControllerProvider = nil
    }

    func subscribeToStashControllerProvider(at activeEra: EraIndex) {
        guard stashControllerProvider == nil, let selectedAccount = settings.selectedAccount else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: selectedAccount.address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.handle(stashItem: stashItem, at: activeEra)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.presenter.didReceiveValidators(result: .failure(error))
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

    func clearNominatorProvider() {
        nominatorProvider?.removeObserver(self)
        nominatorProvider = nil
    }

    func subscribeToNominator(address: String, at activeEra: EraIndex) {
        guard nominatorProvider == nil else {
            return
        }

        guard let nominatorProvider = try? providerFactory
            .getNominationProvider(for: address, runtimeService: runtimeService)
        else {
            return
        }

        self.nominatorProvider = nominatorProvider

        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedNomination>]) in
            let nomination = changes.reduceToLastChange()

            self?.handle(nomination: nomination?.item, stashAddress: address, at: activeEra)
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceiveValidators(result: .failure(error))
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
}
