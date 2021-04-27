import Foundation
import RobinHood

extension YourValidatorsInteractor {
    func clearStashControllerProvider() {
        clearNominatorProvider()

        stashControllerProvider?.removeObserver(self)
        stashControllerProvider = nil
    }

    func subscribeToStashControllerProvider() {
        guard stashControllerProvider == nil, let selectedAccount = settings.selectedAccount else {
            return
        }

        let provider = substrateProviderFactory.createStashItemProvider(for: selectedAccount.address)

        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem = changes.reduceToLastChange()
            self?.handle(stashItem: stashItem)
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

    func subscribeToNominator(address: String) {
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

            self?.handle(nomination: nomination?.item, stashAddress: address)
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

    private func handle(stashItem: StashItem?) {
        if let stashItem = stashItem {
            subscribeToNominator(address: stashItem.stash)
        } else {
            presenter.didReceiveValidators(result: .success(nil))
        }
    }

    private func handle(nomination: Nomination?, stashAddress _: AccountAddress) {
        guard let nomination = nomination else {
            presenter.didReceiveValidators(result: .success(nil))
            return
        }
    }
}
