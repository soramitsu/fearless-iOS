import Foundation
import SoraFoundation

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
        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
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

            provideEraStakersInfo()
            provideNetworkStakingInfo()
            provideRewardCalculator()
        }
    }

    func processEraStakersInfoChanged(event: EraStakersInfoChanged) {
        provideEraStakersInfo()
        provideNetworkStakingInfo()
        provideRewardCalculator()
    }
}

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
    }
}
