import Foundation

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection

        provideNewChain()
        provideSelectedAccount()

        subscribeToPriceChanges()
        subscribeToAccountChanges()
        subscribeToStashControllerProvider()
        subscribeToElectionStatus()
        provideRewardCalculator()
        provideEraStakersInfo()

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if updateAccountAndChainIfNeeded() {
            clearStashControllerProvider()
            subscribeToStashControllerProvider()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if updateAccountAndChainIfNeeded() {
            clearElectionStatusProvider()
            subscribeToElectionStatus()

            clearStashControllerProvider()
            subscribeToStashControllerProvider()

            provideRewardCalculator()

            provideEraStakersInfo()
        }
    }
}
