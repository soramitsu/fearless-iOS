import Foundation
import SoraFoundation
import RobinHood

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
    }

    func setup() {
        setupSelectedAccountAndChainAsset()
        setupSharedState()

        provideNewChain()
        provideSelectedAccount()

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
            let sharedState = stakingSharedState else {
            return
        }

        provideMaxNominatorsPerValidator(from: runtimeService)

        performPriceSubscription()
        performAccountInfoSubscription()
        performStashControllerSubscription()
        performNominatorLimitsSubscripion()

        provideRewardCalculator(from: sharedState.rewardCalculationService)
        provideEraStakersInfo(from: sharedState.eraValidatorService)

        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self

        presenter.networkInfoViewExpansion(isExpanded: commonSettings.stakingNetworkExpansion)
    }

    func save(chainAsset: ChainAsset) {
        guard selectedChainAsset?.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        stakingSettings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.updateAfterChainAssetSave()
        }
    }

    private func updateAfterChainAssetSave() {
        if updateOnAccountOrChainChange() {
            setupSharedState()

            clearNominatorsLimitProviders()
            performNominatorLimitsSubscripion()

            clearStashControllerSubscription()
            performStashControllerSubscription()

            guard
                let chainId = selectedChainAsset?.chain.chainId,
                let runtimeService = chainRegistry.getRuntimeProvider(for: chainId),
                let sharedState = stakingSharedState else {
                return
            }

            provideEraStakersInfo(from: sharedState.eraValidatorService)
            provideNetworkStakingInfo()
            provideRewardCalculator(from: sharedState.rewardCalculationService)
            provideMaxNominatorsPerValidator(from: runtimeService)
        }
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        if updateOnAccountOrChainChange() {
            clearStashControllerSubscription()
            performStashControllerSubscription()
        }
    }

    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        guard let sharedState = stakingSharedState else {
            return
        }

        provideNetworkStakingInfo()
        provideEraStakersInfo(from: sharedState.eraValidatorService)
        provideRewardCalculator(from: sharedState.rewardCalculationService)
    }
}

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
    }
}
