import Foundation
import SoraFoundation
import RobinHood

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func setup() {
        currentAccount = settings.selectedAccount
        currentConnection = settings.selectedConnection

        provideNewChain()
        provideSelectedAccount()
        provideMaxNominatorsPerValidator()

        subscribeToPriceChanges()
        subscribeToAccountChanges()
        subscribeToStashControllerProvider()
        subscribeToNominatorsLimit()
        provideRewardCalculator()
        provideEraStakersInfo()
        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        if updateAccountAndChainIfNeeded() {
            clearStashControllerProvider()
            subscribeToStashControllerProvider()
        }
    }

    func processSelectedConnectionChanged(event _: SelectedConnectionChanged) {
        if updateAccountAndChainIfNeeded() {
            clearNominatorsLimitProviders()
            subscribeToNominatorsLimit()

            clearStashControllerProvider()
            subscribeToStashControllerProvider()

            provideEraStakersInfo()
            provideNetworkStakingInfo()
            provideRewardCalculator()
            provideMaxNominatorsPerValidator()
        }
    }

    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        provideEraStakersInfo()
        provideNetworkStakingInfo()
        provideRewardCalculator()
    }
}

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
    }
}
