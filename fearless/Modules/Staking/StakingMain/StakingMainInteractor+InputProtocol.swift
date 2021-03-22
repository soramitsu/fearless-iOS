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
        provideLockupPeriod()

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

            provideRewardCalculator()

            provideEraStakersInfo()
            provideLockupPeriod()
        }
    }

    func processEraStakersInfoChanged(event: EraStakersInfoChanged) {
        provideEraStakersInfo()
    }
}

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
    }
}
