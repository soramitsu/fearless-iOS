import UIKit
import FearlessUtils
import RobinHood
import SoraKeystore

final class StakingPoolMainInteractor {
    // MARK: - Private properties

    private weak var output: StakingPoolMainInteractorOutput?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private let settings: StakingAssetSettings
    private var rewardCalculationService: RewardCalculatorServiceProtocol
    private var chainAsset: ChainAsset
    private var wallet: MetaAccountModel
    private let operationManager: OperationManagerProtocol
    private let stakingServiceFactory: StakingServiceFactoryProtocol
    private let logger: LoggerProtocol?
    private let commonSettings: SettingsManagerProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?

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
        commonSettings: SettingsManagerProtocol
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

        wallet = newSelectedWallet

        if let accountId = newSelectedWallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        output?.didReceive(wallet: newSelectedWallet)
    }

    private func fetchRewardCalculator() {
        let fetchRewardCalculatorOperation = rewardCalculationService.fetchCalculatorOperation()

        fetchRewardCalculatorOperation.completionBlock = { [weak self] in
            let rewardCalculatorEngine = try? fetchRewardCalculatorOperation.extractNoCancellableResultData()
            self?.output?.didReceive(rewardCalculatorEngine: rewardCalculatorEngine)
        }

        operationManager.enqueue(operations: [fetchRewardCalculatorOperation], in: .transient)
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
    }

    func updateWithChainAsset(_ chainAsset: ChainAsset) {
        clear(singleValueProvider: &priceProvider)

        self.chainAsset = chainAsset

        if let wallet = selectedWalletSettings.value,
           let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            accountInfoSubscriptionAdapter.subscribe(chainAsset: chainAsset, accountId: accountId, handler: self)
        }

        output?.didReceive(chainAsset: chainAsset)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        fetchRewardCalculator()
        fetchNetworkInfo()
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
}

extension StakingPoolMainInteractor: AnyProviderAutoCleaning {}

extension StakingPoolMainInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId _: AccountId,
        chainAsset _: ChainAsset
    ) {
        switch result {
        case let .success(accountInfo):
            output?.didReceive(accountInfo: accountInfo)
        case let .failure(error):
            output?.didReceive(balanceError: error)
        }
    }
}

extension StakingPoolMainInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            output?.didReceive(priceData: priceData)
        case let .failure(error):
            output?.didReceive(priceError: error)
        }
    }
}
