import Foundation

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection

        provideSelectedAccount()
        provideNewChain()

        subscribeToPriceChanges()
        subscribeToAccountChanges()
        subscribeToStashControllerProvider()
        subscribeToElectionStatus()
        subscribeToActiveEra()
        provideRewardCalculator()

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if updateAccountAndChainIfNeeded() {
            clearStashControllerProvider()
            subscribeToStashControllerProvider()

            provideRewardCalculator()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if updateAccountAndChainIfNeeded() {
            clearElectionStatusProvider()
            subscribeToElectionStatus()

            clearActiveEraProvider()
            subscribeToActiveEra()

            clearStashControllerProvider()
            subscribeToStashControllerProvider()

            provideRewardCalculator()
        }
    }
}
