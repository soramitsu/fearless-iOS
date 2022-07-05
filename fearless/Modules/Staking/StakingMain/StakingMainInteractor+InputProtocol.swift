import Foundation
import SoraFoundation
import RobinHood

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
    func refresh() {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
        rewardAnalyticsProvider?.refresh()

        guard
            let wallet = selectedWalletSettings.value,
            let chainAsset = stakingSettings.value,
            let response = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return
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

        //  Only relaychain, check if it ever needed for parachain
        setupChainRemoteSubscription()
        setupAccountRemoteSubscription()

        sharedState.eraValidatorService.setup()
        sharedState.rewardCalculationService.setup()

        eraInfoOperationFactory = selectedChainAsset?.chain.isEthereumBased == true ? ParachainStakingInfoOperationFactory() : RelaychainStakingInfoOperationFactory()

        provideNewChain()
        provideSelectedAccount()

        guard
            let chainId = selectedChainAsset?.chain.chainId,
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return
        }

        //  Only relaychain
        provideMaxNominatorsPerValidator(from: runtimeService)

        performPriceSubscription()
        performAccountInfoSubscription()

        //  Only relaychain
        performStashControllerSubscription()
        performNominatorLimitsSubscripion()

        // Parachain

        if let chainAsset = selectedChainAsset,
           let accountId = selectedWalletSettings.value?.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            delegatorStateProvider = subscribeToDelegatorState(
                for: chainId,
                accountId: accountId
            )
        }

        fetchParachainInfo()

        //  Should be done by separate task
        provideRewardCalculator(from: sharedState.rewardCalculationService)
        provideEraStakersInfo(from: sharedState.eraValidatorService)

        provideNetworkStakingInfo()

        eventCenter.add(observer: self, dispatchIn: .main)

        applicationHandler.delegate = self

        presenter?.networkInfoViewExpansion(isExpanded: commonSettings.stakingNetworkExpansion)
    }

    func save(chainAsset: ChainAsset) {
        guard selectedChainAsset?.chainAssetId != chainAsset.chainAssetId, let wallet = selectedAccount else {
            return
        }

        stakingSettings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.updateAfterChainAssetSave()
            self?.updateAfterSelectedAccountChange()
        }
    }

    private func updateAfterChainAssetSave() {
        guard let newSelectedChainAsset = stakingSettings.value else {
            return
        }

        switch newSelectedChainAsset.stakingType {
        case .relayChain:
            eraInfoOperationFactory = RelaychainStakingInfoOperationFactory()
        case .paraChain:
            eraInfoOperationFactory = ParachainStakingInfoOperationFactory()

        case .none:
            break
        }

        selectedChainAsset.map { clearChainRemoteSubscription(for: $0.chain.chainId) }

        selectedChainAsset = newSelectedChainAsset

        setupChainRemoteSubscription()

        updateSharedState()

        provideNewChain()

        clear(singleValueProvider: &priceProvider)
        clear(dataProvider: &delegatorStateProvider)
        performPriceSubscription()

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

        if let chainAsset = selectedChainAsset,
           let accountId = selectedWalletSettings.value?.fetch(for: chainAsset.chain.accountRequest())?.accountId, chainAsset.chain.isEthereumBased {
            delegatorStateProvider = subscribeToDelegatorState(
                for: chainId,
                accountId: accountId
            )
        }

        fetchParachainInfo()
    }

    func fetchBottomDelegations(accountIds: [AccountId]) {
        let accountIdsClosure = { [accountIds] in
            accountIds
        }

        let delegationScheduledRequests = collatorOperationFactory.delegationScheduledRequests(accountIdsClosure: accountIdsClosure)

        delegationScheduledRequests.targetOperation.completionBlock = { [weak self] in
            let requests = try? delegationScheduledRequests.targetOperation.extractNoCancellableResultData()
            DispatchQueue.main.async {
                self?.presenter?.didReceiveScheduledRequests(requests: requests)
            }
        }

        let bottomDelegationsOperation = collatorOperationFactory.collatorBottomDelegations(accountIdsClosure: accountIdsClosure)

        bottomDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let bottomDelegations = try? bottomDelegationsOperation.targetOperation.extractNoCancellableResultData()
                self?.presenter?.didReceiveBottomDelegations(delegations: bottomDelegations)
            }
        }

        operationManager.enqueue(operations: delegationScheduledRequests.allOperations + bottomDelegationsOperation.allOperations, in: .transient)
    }

    private func fetchParachainInfo() {
        let roundOperation = collatorOperationFactory.round()
        let currentBlockOperation = collatorOperationFactory.currentBlock()

        currentBlockOperation.targetOperation.completionBlock = { [weak self] in
            let currentBlock = try? currentBlockOperation.targetOperation.extractNoCancellableResultData()

            if let block = currentBlock, let currentBlockvalue = UInt32(block) {
                DispatchQueue.main.async {
                    self?.presenter?.didReceiveCurrentBlock(currentBlock: currentBlockvalue)
                }
            }
        }

        roundOperation.targetOperation.completionBlock = { [weak self] in
            let roundInfo = try? roundOperation.targetOperation.extractNoCancellableResultData()
            DispatchQueue.main.async {
                self?.presenter?.didReceiveRound(round: roundInfo)
            }
        }

        operationManager.enqueue(operations: roundOperation.allOperations + currentBlockOperation.allOperations, in: .transient)
    }

    private func updateAfterSelectedAccountChange() {
        clearAccountRemoteSubscription()
        accountInfoSubscriptionAdapter.reset()
        clearStashControllerSubscription()

        guard let selectedChain = selectedChainAsset?.chain,
              let selectedMetaAccount = selectedWalletSettings.value,
              let newSelectedAccount = selectedMetaAccount.fetch(for: selectedChain.accountRequest()) else {
            return
        }

        selectedAccount = newSelectedAccount

        setupAccountRemoteSubscription()

        performAccountInfoSubscription()

        provideSelectedAccount()

        performStashControllerSubscription()

        if let chainAsset = selectedChainAsset,
           let accountId = selectedWalletSettings.value?.fetch(for: chainAsset.chain.accountRequest())?.accountId, chainAsset.chain.isEthereumBased {
            delegatorStateProvider = subscribeToDelegatorState(
                for: chainAsset.chain.chainId,
                accountId: accountId
            )
        } else {
            presenter?.didReceive(delegationInfos: [])
        }
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

    func processChainsUpdated(event: ChainsUpdatedEvent) {
        guard event.updatedChains.contains(where: {
            $0.identifier == selectedChainAsset?.chain.identifier
        }) else { return }
        updateAfterChainAssetSave()
        updateAfterSelectedAccountChange()
    }

    func processMetaAccountChanged(event _: MetaAccountModelChangedEvent) {
        priceProvider?.refresh()
    }
}

extension StakingMainInteractor: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        priceProvider?.refresh()
        totalRewardProvider?.refresh()
        rewardAnalyticsProvider?.refresh()
    }
}
