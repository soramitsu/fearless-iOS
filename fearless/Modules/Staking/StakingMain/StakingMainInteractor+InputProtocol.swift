import Foundation
import SoraFoundation
import RobinHood
import SSFModels

extension StakingMainInteractor: StakingMainInteractorInputProtocol {
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

        eraInfoOperationFactory = selectedChainAsset?.stakingType?.isParachain == true
            ? ParachainStakingInfoOperationFactory()
            : RelaychainStakingInfoOperationFactory()

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
                for: chainAsset,
                accountId: accountId
            )

            if let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) {
                subscribeRewardsAnalytics(for: address)
            }
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
        clear(singleValueProvider: &rewardAssetPriceProvider)
        clear(dataProvider: &delegatorStateProvider)
        collatorIds = nil
        performPriceSubscription()
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

        if
            let chainAsset = selectedChainAsset,
            let accountId = selectedWalletSettings.value?.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            chainAsset.chain.isEthereumBased {
            delegatorStateProvider = subscribeToDelegatorState(
                for: chainAsset,
                accountId: accountId
            )

            if let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) {
                subscribeRewardsAnalytics(for: address)
            }
        }

        fetchParachainInfo()
    }

    func fetchCollatorsDelegations(accountIds: [AccountId]) {
        let accountIdsClosure = { [accountIds] in
            accountIds
        }

        let delegationScheduledRequests = collatorOperationFactory
            .delegationScheduledRequests(accountIdsClosure: accountIdsClosure)

        delegationScheduledRequests.targetOperation.completionBlock = { [weak self] in
            let requests = try? delegationScheduledRequests.targetOperation.extractNoCancellableResultData()
            DispatchQueue.main.async {
                self?.presenter?.didReceiveScheduledRequests(requests: requests)
            }
        }

        let bottomDelegationsOperation = collatorOperationFactory
            .collatorBottomDelegations(accountIdsClosure: accountIdsClosure)

        bottomDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let bottomDelegations = try? bottomDelegationsOperation.targetOperation.extractNoCancellableResultData()
                self?.presenter?.didReceiveBottomDelegations(delegations: bottomDelegations)
            }
        }

        let topDelegationsOperation = collatorOperationFactory
            .collatorTopDelegations(accountIdsClosure: accountIdsClosure)

        topDelegationsOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                let topDelegations = try? topDelegationsOperation.targetOperation.extractNoCancellableResultData()
                self?.presenter?.didReceiveTopDelegations(delegations: topDelegations)
            }
        }

        let operations = [
            delegationScheduledRequests.allOperations,
            bottomDelegationsOperation.allOperations,
            topDelegationsOperation.allOperations
        ].reduce([], +)

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func fetchParachainInfo() {
        let roundOperation = collatorOperationFactory.round()
        let currentBlockOperation = collatorOperationFactory.currentBlock()

        currentBlockOperation.targetOperation.completionBlock = { [weak self] in
            let currentBlock = try? currentBlockOperation.targetOperation.extractNoCancellableResultData()

            if let block = currentBlock, let currentBlockValue = UInt32(block) {
                DispatchQueue.main.async {
                    self?.presenter?.didReceiveCurrentBlock(currentBlock: currentBlockValue)
                }
            }
        }

        roundOperation.targetOperation.completionBlock = { [weak self] in
            let roundInfo = try? roundOperation.targetOperation.extractNoCancellableResultData()
            DispatchQueue.main.async {
                self?.presenter?.didReceiveRound(round: roundInfo)
            }
        }

        let operations = [
            roundOperation.allOperations,
            currentBlockOperation.allOperations
        ].reduce([], +)

        operationManager.enqueue(operations: operations, in: .transient)
    }

    private func updateAfterSelectedAccountChange() {
        clearAccountRemoteSubscription()
        accountInfoSubscriptionAdapter.reset()
        clearStashControllerSubscription()

        clear(dataProvider: &delegatorStateProvider)
        collatorIds = nil

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
        setupAccountRemoteSubscription()
        performAccountInfoSubscription()
        provideSelectedAccount()
        performStashControllerSubscription()
        fetchParachainInfo()

        if
            let chainAsset = selectedChainAsset,
            let accountId = selectedWalletSettings.value?.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            chainAsset.chain.isEthereumBased {
            delegatorStateProvider = subscribeToDelegatorState(
                for: chainAsset,
                accountId: accountId
            )

            if let address = try? AddressFactory.address(for: accountId, chain: chainAsset.chain) {
                subscribeRewardsAnalytics(for: address)
            }
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
