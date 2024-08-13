import UIKit
import SSFUtils
import RobinHood
import SoraKeystore
import SSFModels

final class StakingPoolMainInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: StakingPoolMainInteractorOutput?
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private var stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private let settings: StakingAssetSettings
    private var rewardCalculationService: RewardCalculatorServiceProtocol
    private var chainAsset: ChainAsset
    private var wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private let stakingServiceFactory: StakingServiceFactoryProtocol
    private let logger: LoggerProtocol?
    private let commonSettings: SettingsManagerProtocol
    private var eraValidatorService: EraValidatorServiceProtocol
    private let chainRegistry: ChainRegistryProtocol
    private var eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private let eventCenter: EventCenterProtocol
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let poolStakingAccountUpdatingService: PoolStakingAccountUpdatingServiceProtocol
    private let stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol
    private let accountOperationFactory: AccountOperationFactoryProtocol
    private let existentialDepositService: ExistentialDepositServiceProtocol
    private var validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    private var chainSubscriptionId: UUID?

    deinit {
        clearChainRemoteSubscription(for: chainAsset.chain.chainId)
    }

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        settings: StakingAssetSettings,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        operationManager: OperationManagerProtocol,
        stakingServiceFactory: StakingServiceFactoryProtocol,
        logger: LoggerProtocol?,
        commonSettings: SettingsManagerProtocol,
        eraValidatorService: EraValidatorServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        eventCenter: EventCenterProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        poolStakingAccountUpdatingService: PoolStakingAccountUpdatingServiceProtocol,
        accountOperationFactory: AccountOperationFactoryProtocol,
        existentialDepositService: ExistentialDepositServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        stakingAccountUpdatingService: StakingAccountUpdatingServiceProtocol,
        stakingRemoteSubscriptionService: StakingRemoteSubscriptionServiceProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.selectedWalletSettings = selectedWalletSettings
        self.settings = settings
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.rewardCalculationService = rewardCalculationService
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.operationManager = operationManager
        self.stakingServiceFactory = stakingServiceFactory
        self.logger = logger
        self.commonSettings = commonSettings
        self.eraValidatorService = eraValidatorService
        self.chainRegistry = chainRegistry
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.eventCenter = eventCenter
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.poolStakingAccountUpdatingService = poolStakingAccountUpdatingService
        self.accountOperationFactory = accountOperationFactory
        self.existentialDepositService = existentialDepositService
        self.validatorOperationFactory = validatorOperationFactory
        self.stakingAccountUpdatingService = stakingAccountUpdatingService
        self.stakingRemoteSubscriptionService = stakingRemoteSubscriptionService
    }

    func clearChainRemoteSubscription(for chainId: ChainModel.Id) {
        if let chainSubscriptionId = chainSubscriptionId {
            stakingRemoteSubscriptionService.detachFromGlobalData(
                for: chainSubscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil,
                stakingType: chainAsset.stakingType
            )

            self.chainSubscriptionId = nil
        }
    }

    func setupChainRemoteSubscription() {
        chainSubscriptionId = stakingRemoteSubscriptionService.attachToGlobalData(
            for: chainAsset.chain.chainId,
            queue: nil,
            closure: nil,
            stakingType: chainAsset.stakingType
        )
    }

    private func updateDependencies() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let rewardOperationFactory = RewardOperationFactory.factory(chain: chainAsset.chain)

        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageOperationFactory,
            identityOperationFactory: identityOperationFactory,
            subqueryOperationFactory: rewardOperationFactory,
            chainRegistry: chainRegistry
        )

        do {
            let eraValidatorService = try stakingServiceFactory.createEraValidatorService(
                for: chainAsset.chain
            )

            let rewardCalculatorService = try stakingServiceFactory.createRewardCalculatorService(
                for: chainAsset,
                assetPrecision: Int16(chainAsset.asset.precision),
                validatorService: eraValidatorService,
                collatorOperationFactory: collatorOperationFactory
            )

            rewardCalculationService = rewardCalculatorService

            eraValidatorService.setup()
            rewardCalculatorService.setup()
        } catch {
            logger?.error("Couldn't create shared state")
        }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let stakingPoolOperationFactory = StakingPoolOperationFactory(
            chainAsset: chainAsset,
            storageRequestFactory: requestFactory,
            chainRegistry: chainRegistry
        )

        self.stakingPoolOperationFactory = stakingPoolOperationFactory

        validatorOperationFactory = RelaychainValidatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculationService,
            storageRequestFactory: storageOperationFactory,
            identityOperationFactory: identityOperationFactory,
            chainRegistry: chainRegistry
        )
    }

    private func updateAfterChainAssetSave() {
        guard let newSelectedChainAsset = settings.value else {
            return
        }

        chainAsset = newSelectedChainAsset

        updateDependencies()

        updateWithChainAsset(chainAsset)
    }

    private func updateAfterSelectedAccountChange() {
        guard let newSelectedWallet = SelectedWalletSettings.shared.value else {
            return
        }

        stakingAccountUpdatingService.clearSubscription()
        poolStakingAccountUpdatingService.clearSubscription()
        clear(dataProvider: &poolMemberProvider)
        clear(dataProvider: &nominationProvider)
        clear(dataProvider: &activeEraProvider)
        clearChainRemoteSubscription(for: chainAsset.chain.chainId)

        wallet = newSelectedWallet

        if let accountId = newSelectedWallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            try? poolStakingAccountUpdatingService.setupSubscription(
                for: accountId,
                chainAsset: chainAsset,
                chainFormat: chainAsset.chain.chainFormat,
                stakingType: .relaychain
            )
            poolMemberProvider = subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)

            fetchPendingRewards()
        }

        output?.didReceive(wallet: newSelectedWallet)

        fetchStakeInfo()

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
        setupChainRemoteSubscription()
    }

    private func fetchRewardCalculator() {
        let fetchRewardCalculatorOperation = rewardCalculationService.fetchCalculatorOperation()

        fetchRewardCalculatorOperation.completionBlock = { [weak self] in
            let rewardCalculatorEngine = try? fetchRewardCalculatorOperation.extractNoCancellableResultData()
            self?.output?.didReceive(rewardCalculatorEngine: rewardCalculatorEngine)
        }

        operationManager.enqueue(operations: [fetchRewardCalculatorOperation], in: .transient)
    }

    private func fetchStakeInfo() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        let stakeInfoOperation = stakingPoolOperationFactory.fetchStakingPoolMembers(accountId: accountId)

        stakeInfoOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let stakeInfo = try stakeInfoOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(stakeInfo: stakeInfo)
                } catch {
                    self?.output?.didReceiveError(.stakeInfoError(error: error))
                }
            }
        }

        operationManager.enqueue(operations: stakeInfoOperation.allOperations, in: .transient)
    }

    private func fetchPoolRewards(poolId: String) {
        let stakeInfoOperation = stakingPoolOperationFactory.fetchPoolRewardsOperation(poolId: poolId)

        stakeInfoOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let poolRewards = try stakeInfoOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(poolRewards: poolRewards)
                } catch {
                    self?.output?.didReceiveError(.poolRewardsError(error: error))
                }
            }
        }

        operationManager.enqueue(operations: stakeInfoOperation.allOperations, in: .transient)
    }

    private func fetchPoolInfo(poolId: String) {
        let fetchPoolInfoOperation = stakingPoolOperationFactory.fetchBondedPoolOperation(poolId: poolId)
        fetchPoolInfoOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let stakingPool = try fetchPoolInfoOperation.targetOperation.extractNoCancellableResultData()

                DispatchQueue.main.async {
                    self?.output?.didReceive(stakingPool: stakingPool)
                }
            } catch {}
        }

        operationManager.enqueue(operations: fetchPoolInfoOperation.allOperations, in: .transient)
    }

    func provideEraStakersInfo() {
        let operation = eraValidatorService.fetchInfoOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.output?.didReceive(eraStakersInfo: info)
                    self?.fetchEraCompletionTime()
                } catch {
                    self?.output?.didReceiveError(.eraStakersInfoError(error: error))
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func fetchEraCompletionTime() {
        let chainId = chainAsset.chain.chainId

        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            output?.didReceive(eraCountdownResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
            return
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            output?.didReceive(eraCountdownResult: .failure(ChainRegistryError.connectionUnavailable))
            return
        }

        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.output?.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }

    private func fetchNetworkInfo() {
        let fetchMinJoinBondOperation = stakingPoolOperationFactory.fetchMinJoinBondOperation()
        let fetchMinCreateBondOperation = stakingPoolOperationFactory.fetchMinCreateBondOperation()
        let maxStakingPoolsCountOperation = stakingPoolOperationFactory.fetchMaxStakingPoolsCount()
        let maxPoolsMembersOperation = stakingPoolOperationFactory.fetchMaxPoolMembers()
        let existingPoolsCountOperation = stakingPoolOperationFactory.fetchCounterForBondedPools()
        let maxPoolMembersPerPoolOperation = stakingPoolOperationFactory.fetchMaxPoolMembersPerPool()

        let mapOperation = ClosureOperation<StakingPoolNetworkInfo> {
            let minJoinBond = try? fetchMinJoinBondOperation.targetOperation.extractNoCancellableResultData()
            let minCreateBond = try? fetchMinCreateBondOperation.targetOperation.extractNoCancellableResultData()
            let maxPoolsCount = try? maxStakingPoolsCountOperation.targetOperation.extractNoCancellableResultData()
            let maxPoolsMembers = try? maxPoolsMembersOperation.targetOperation.extractNoCancellableResultData()
            let existingPoolsCount = try? existingPoolsCountOperation.targetOperation.extractNoCancellableResultData()
            let maxPoolMembersPerPool = try? maxPoolMembersPerPoolOperation.targetOperation.extractNoCancellableResultData()

            return StakingPoolNetworkInfo(
                minJoinBond: minJoinBond,
                minCreateBond: minCreateBond,
                existingPoolsCount: existingPoolsCount,
                possiblePoolsCount: maxPoolsCount,
                maxMembersInPool: maxPoolMembersPerPool,
                maxPoolsMembers: maxPoolsMembers
            )
        }

        mapOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let networkInfo = try mapOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(networkInfo: networkInfo)
                } catch {
                    self?.output?.didReceiveError(.networkInfoError(error: error))
                }
            }
        }

        let dependencies = [fetchMinJoinBondOperation.targetOperation,
                            fetchMinCreateBondOperation.targetOperation,
                            maxStakingPoolsCountOperation.targetOperation,
                            maxPoolsMembersOperation.targetOperation,
                            existingPoolsCountOperation.targetOperation,
                            maxPoolMembersPerPoolOperation.targetOperation]

        dependencies.forEach {
            mapOperation.addDependency($0)
        }

        var allOperations: [Operation] = [mapOperation]
        allOperations.append(contentsOf: fetchMinJoinBondOperation.allOperations)
        allOperations.append(contentsOf: fetchMinCreateBondOperation.allOperations)
        allOperations.append(contentsOf: maxStakingPoolsCountOperation.allOperations)
        allOperations.append(contentsOf: maxPoolsMembersOperation.allOperations)
        allOperations.append(contentsOf: existingPoolsCountOperation.allOperations)
        allOperations.append(contentsOf: maxPoolMembersPerPoolOperation.allOperations)

        operationManager.enqueue(
            operations: allOperations,
            in: .transient
        )
    }

    private func fetchPendingRewards() {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        let pendingRewardsOperation = stakingPoolOperationFactory.fetchPendingRewards(accountId: accountId)
        pendingRewardsOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try pendingRewardsOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(pendingRewards: result)
                } catch {
                    self?.output?.didReceive(pendingRewardsError: error)
                }
            }
        }
        operationManager.enqueue(operations: pendingRewardsOperation.allOperations, in: .transient)
    }
}

// MARK: - StakingPoolMainInteractorInput

extension StakingPoolMainInteractor: StakingPoolMainInteractorInput {
    func setup(with output: StakingPoolMainInteractorOutput) {
        self.output = output

        updateWithChainAsset(chainAsset)

        rewardCalculationService.setup()

        fetchRewardCalculator()
        fetchStakeInfo()

        eventCenter.add(observer: self)
    }

    func updateWithChainAsset(_ chainAsset: ChainAsset) {
        output?.didReceive(rewardCalculatorEngine: nil)
        output?.didReceive(stakeInfo: nil)
        output?.didReceive(stakingPool: nil)
        output?.didReceive(poolAccountInfo: nil)
        clear(dataProvider: &poolMemberProvider)
        clear(dataProvider: &nominationProvider)
        clear(dataProvider: &activeEraProvider)

        poolStakingAccountUpdatingService.clearSubscription()
        stakingAccountUpdatingService.clearSubscription()
        clearChainRemoteSubscription(for: chainAsset.chain.chainId)

        self.chainAsset = chainAsset

        if let wallet = selectedWalletSettings.value,
           let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            poolMemberProvider = subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)
            try? poolStakingAccountUpdatingService.setupSubscription(
                for: accountId,
                chainAsset: chainAsset,
                chainFormat: chainAsset.chain.chainFormat,
                stakingType: .relaychain
            )

            fetchPendingRewards()
        }

        output?.didReceive(chainAsset: chainAsset)

        fetchRewardCalculator()
        fetchNetworkInfo()
        fetchStakeInfo()
        provideEraStakersInfo()
        setupChainRemoteSubscription()

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        if let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) {
            fetchCompoundConstant(
                for: .nominationPoolsPalletId,
                runtimeCodingService: runtimeService,
                operationManager: operationManager
            ) { [weak self] (result: Result<Data, Error>) in
                self?.output?.didReceive(palletIdResult: result)
            }
        } else {
            output?.didReceive(palletIdResult: .failure(ChainRegistryError.runtimeMetadaUnavailable))
        }

        existentialDepositService.fetchExistentialDeposit(chainAsset: chainAsset) { [weak self] result in
            self?.output?.didReceive(existentialDepositResult: result)
        }
    }

    func save(chainAsset: ChainAsset) {
        guard self.chainAsset.chainAssetId != chainAsset.chainAssetId else {
            return
        }

        settings.save(value: chainAsset, runningCompletionIn: .main) { [weak self] _ in
            self?.updateAfterChainAssetSave()
            self?.updateAfterSelectedAccountChange()
        }
    }

    func saveNetworkInfoViewExpansion(isExpanded: Bool) {
        commonSettings.stakingNetworkExpansion = isExpanded
    }

    func fetchPoolBalance(poolRewardAccountId: AccountId) {
        let fetchAccountInfoOperation = accountOperationFactory.createAccountInfoFetchOperation(poolRewardAccountId)

        fetchAccountInfoOperation.targetOperation.completionBlock = { [weak self] in
            let poolAccountInfo = try? fetchAccountInfoOperation.targetOperation.extractNoCancellableResultData()

            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(poolAccountInfo: poolAccountInfo)
            }
        }

        operationManager.enqueue(operations: fetchAccountInfoOperation.allOperations, in: .transient)
    }

    func fetchPoolNomination(poolStashAccountId: AccountId) {
        do {
            try stakingAccountUpdatingService.setupSubscription(
                for: poolStashAccountId,
                chainAsset: chainAsset,
                chainFormat: chainAsset.chain.chainFormat,
                stakingType: .relaychain
            )
        } catch {
            output?.didReceiveError(.nominationError(error: error))
        }

        nominationProvider = subscribeNomination(for: poolStashAccountId, chainAsset: chainAsset)
    }
}

extension StakingPoolMainInteractor: AnyProviderAutoCleaning {}

extension StakingPoolMainInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        guard self.chainAsset.chainAssetId == chainAsset.chainAssetId else {
            return
        }

        guard wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId == accountId else {
            return
        }

        switch result {
        case let .success(accountInfo):
            output?.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            output?.didReceiveError(.balanceError(error: error))
        }
    }
}

extension StakingPoolMainInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        updateAfterSelectedAccountChange()
    }
}

extension StakingPoolMainInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<StakingPoolMember?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    ) {
        guard chainAsset.chain.chainId == chainId,
              wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId == accountId else {
            return
        }

        switch result {
        case let .success(poolMember):
            if let poolId = poolMember?.poolId.value {
                fetchPoolInfo(poolId: poolId.description)
                fetchPoolRewards(poolId: poolId.description)
            }

            fetchPendingRewards()

            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(stakeInfo: poolMember)
            }
        case let .failure(error):
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceiveError(.stakeInfoError(error: error))
            }
        }
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(nomination):
            output?.didReceive(nomination: nomination)
        case let .failure(error):
            output?.didReceiveError(.nominationError(error: error))
        }
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case let .success(eraInfo):
            output?.didReceive(era: eraInfo?.index)
        case let .failure(error):
            output?.didReceiveError(.eraStakersInfoError(error: error))
        }
    }
}
