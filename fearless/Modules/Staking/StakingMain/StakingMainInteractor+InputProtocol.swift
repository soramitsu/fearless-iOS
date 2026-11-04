import Foundation
import SoraFoundation
import RobinHood
import SSFModels

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func changeActiveState(_ isActive: Bool) {
        self.isActive = isActive

        if let selectedChain = selectedChainAsset?.chain,
           let selectedMetaAccount = selectedWalletSettings.value,
           let newSelectedAccount = selectedMetaAccount.fetch(for: selectedChain.accountRequest()),
           newSelectedAccount != selectedAccount {
            updateAfterSelectedAccountChange()
        }
    }

    func updatePrices() {
        updateAfterChainAssetSave()
        updateAfterSelectedAccountChange()
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
    }

    func setup() {
        setupSelectedAccountAndChainAsset()

        setupChainRemoteSubscription()
        setupAccountRemoteSubscription()

        sharedState.eraValidatorService.setup()
        sharedState.rewardCalculationService.setup()

        eraInfoOperationFactory = RelaychainStakingInfoOperationFactory()

        provideNewChain()
        provideSelectedAccount()

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return
        }

        //  Only relaychain
        provideMaxNominatorsPerValidator(from: runtimeService)

        performAccountInfoSubscription()

        //  Only relaychain
        performStashControllerSubscription()
        performNominatorLimitsSubscripion()

        //  Should be done by separate task
        provideRewardCalculator(from: sharedState.rewardCalculationService)
        provideEraStakersInfo(from: sharedState.eraValidatorService)

        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self

        presenter?.networkInfoViewExpansion(isExpanded: commonSettings.stakingNetworkExpansion)
    }

    func save(chainAsset: ChainAsset) {
        guard selectedChainAsset?.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        stakingSettings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.updateAfterChainAssetSave()
            self?.updateAfterSelectedAccountChange()
        }
    }

    private func updateAfterChainAssetSave() {
        guard let newSelectedChainAsset = stakingSettings.value else {
            selectedChainAsset.map { clearChainRemoteSubscription(for: $0.chain.chainId) }
            clearAccountRemoteSubscription()
            accountInfoSubscriptionAdapter.reset()
            clearStashControllerSubscription()
            clear(streamableProvider: &controllerAccountProvider)
            clearNominatorsLimitProviders()
            selectedChainAsset = nil
            selectedAccount = nil
            rewardChainAsset = nil
            sharedState.eraValidatorService.throttle()
            sharedState.rewardCalculationService.throttle()
            presenter?.didReceive(newChainAsset: nil)
            return
        }

        switch newSelectedChainAsset.stakingType {
        case .relaychain, .sora, .ternoa:
            eraInfoOperationFactory = RelaychainStakingInfoOperationFactory()
        case .none:
            break
        }

        selectedChainAsset.map { clearChainRemoteSubscription(for: $0.chain.chainId) }

        selectedChainAsset = newSelectedChainAsset

        setupChainRemoteSubscription()

        updateSharedState()

        provideNewChain()

        provideRewardChainAsset()

        clearNominatorsLimitProviders()
        performNominatorLimitsSubscripion()

        clearStashControllerSubscription()
        performStashControllerSubscription()

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return
        }

        provideEraStakersInfo(from: sharedState.eraValidatorService)
        provideNetworkStakingInfo()
        provideRewardCalculator(from: sharedState.rewardCalculationService)
        provideMaxNominatorsPerValidator(from: runtimeService)
    }

    private func updateAfterSelectedAccountChange() {
        guard isActive else {
            return
        }

        clearAccountRemoteSubscription()
        accountInfoSubscriptionAdapter.reset()
        clearStashControllerSubscription()

        guard let selectedChain = selectedChainAsset?.chain,
              let selectedMetaAccount = selectedWalletSettings.value,
              let newSelectedAccount = selectedMetaAccount.fetch(for: selectedChain.accountRequest()) else {
            sharedState.settings.performSetup { [weak self] result in
                switch result {
                case let .success(chainAsset):
                    if let chainAsset = chainAsset {
                        self?.save(chainAsset: chainAsset)
                    }
                case let .failure(error):
                    self?.logger?.error("updateAfterSelectedAccountChange: \(error)")
                }
            }

            return
        }

        selectedAccount = newSelectedAccount
        presenter?.didReceive(selectedWallet: selectedMetaAccount)
        if let chainId = selectedChainAsset?.chain.chainId,
           AssetHubStakingRoute.staking(on: chainId) != nil {
            provideNetworkStakingInfo()
        }
        setupAccountRemoteSubscription()
        performAccountInfoSubscription()
        provideSelectedAccount()
        performStashControllerSubscription()
    }
}

extension StakingMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        updateAfterSelectedAccountChange()
    }

    func processEraStakersInfoChanged(event _: EraStakersInfoChanged) {
        provideNetworkStakingInfo()
        provideEraStakersInfo(from: sharedState.eraValidatorService)
        provideRewardCalculator(from: sharedState.rewardCalculationService)
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        stakingSettings.setup()
        updateAfterChainAssetSave()
        updateAfterSelectedAccountChange()
    }
}

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        totalRewardProvider?.refresh()
    }
}
