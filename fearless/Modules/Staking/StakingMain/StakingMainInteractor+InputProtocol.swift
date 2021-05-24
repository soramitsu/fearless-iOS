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
        subscribeToElectionStatus()
        provideRewardCalculator()
        provideEraStakersInfo()
        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self
    }

    func fetchController(for address: AccountAddress) {
        let operation = accountRepository.fetchOperation(by: address, options: RepositoryFetchOptions())

        operation.completionBlock = { [weak presenter] in
            DispatchQueue.main.async {
                do {
                    let accountItem = try operation.extractNoCancellableResultData()
                    presenter?.didFetchController(accountItem, for: address)
                } catch {
                    presenter?.didReceive(fetchControllerError: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
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
            clearElectionStatusProvider()
            subscribeToElectionStatus()

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
