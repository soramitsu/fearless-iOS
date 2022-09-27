import UIKit
import FearlessUtils
import RobinHood
import SoraKeystore

final class StakingPoolMainInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: StakingPoolMainInteractorOutput?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
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
    private let stakingAccountUpdatingService: PoolStakingAccountUpdatingServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?

    init(
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        settings: StakingAssetSettings,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        rewardCalculationService: RewardCalculatorServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
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
        stakingAccountUpdatingService: PoolStakingAccountUpdatingServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.selectedWalletSettings = selectedWalletSettings
        self.settings = settings
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.rewardCalculationService = rewardCalculationService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
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
        self.stakingAccountUpdatingService = stakingAccountUpdatingService
        self.runtimeService = runtimeService
    }

    private func updateDependencies() {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)
        else {
            return
        }

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let subqueryOperationFactory = SubqueryRewardOperationFactory(
            url: chainAsset.chain.externalApi?.staking?.url
        )

        let collatorOperationFactory = ParachainCollatorOperationFactory(
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityOperationFactory: identityOperationFactory,
            subqueryOperationFactory: subqueryOperationFactory
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
            runtimeService: runtimeService,
            engine: connection
        )

        self.stakingPoolOperationFactory = stakingPoolOperationFactory
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

        wallet = newSelectedWallet

        if let accountId = newSelectedWallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            try? stakingAccountUpdatingService.setupSubscription(for: accountId, chainAsset: chainAsset, chainFormat: chainAsset.chain.chainFormat, stakingType: .relayChain)
        }

        output?.didReceive(wallet: newSelectedWallet)

        fetchStakeInfo()
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
                    self?.output?.didReceive(stakeInfoError: error)
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
                    self?.output?.didReceive(poolRewardsError: error)
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
                    self?.output?.didReceive(eraStakersInfoError: error)
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
                    self?.output?.didReceive(networkInfoError: error)
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
        clear(singleValueProvider: &priceProvider)
        clear(dataProvider: &poolMemberProvider)
        stakingAccountUpdatingService.clearSubscription()

        self.chainAsset = chainAsset

        if let wallet = selectedWalletSettings.value,
           let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
            poolMemberProvider = subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)
            try? stakingAccountUpdatingService.setupSubscription(
                for: accountId,
                chainAsset: chainAsset,
                chainFormat: chainAsset.chain.chainFormat,
                stakingType: .relayChain
            )
        }

        output?.didReceive(chainAsset: chainAsset)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        fetchRewardCalculator()
        fetchNetworkInfo()
        fetchStakeInfo()
        provideEraStakersInfo()
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

    func fetchPoolBalance(poolAccountId: AccountId) {
        accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: poolAccountId, handler: self)
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
            switch result {
            case let .success(accountInfo):
                output?.didReceive(poolAccountInfo: accountInfo)
            case let .failure(error):
                output?.didReceive(balanceError: error)
            }
            return
        }

        switch result {
        case let .success(accountInfo):
            output?.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            output?.didReceive(balanceError: error)
        }
    }
}

extension StakingPoolMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        guard chainAsset.asset.priceId == priceId else {
            return
        }

        switch result {
        case let .success(priceData):
            print("did receive price data: ", priceId)
            output?.didReceive(priceData: priceData)
        case let .failure(error):
            output?.didReceive(priceError: error)
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

            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(stakeInfo: poolMember)
            }
        case let .failure(error):
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(stakeInfoError: error)
            }
        }
    }
}
