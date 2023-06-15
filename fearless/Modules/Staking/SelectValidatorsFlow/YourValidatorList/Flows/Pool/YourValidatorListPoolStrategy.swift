import Foundation
import RobinHood
import SSFModels

protocol YourValidatorListPoolStrategyOutput {
    func didReceive(stakeInfo: StakingPoolMember?)
    func didReceive(stakingPool: StakingPool?)
    func didReceive(error: Error)
    func didReceive(palletIdResult: Result<Data, Error>)
    func didReceiveValidators(result: Result<YourValidatorsModel, Error>)
    func didReceive(nomination: Nomination?)
}

final class YourValidatorListPoolStrategy: RuntimeConstantFetching, AnyProviderAutoCleaning {
    private var output: YourValidatorListPoolStrategyOutput?
    private var stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private var chainAsset: ChainAsset
    private var wallet: MetaAccountModel
    private var eraValidatorService: EraValidatorServiceProtocol
    private let operationManager: OperationManagerProtocol
    private let chainRegistry: ChainRegistryProtocol
    private var eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?

    private var activeEraInfo: ActiveEraInfo?
    private var stakingPool: StakingPool?
    private var palletId: Data?
    private var nomination: Nomination?

    init(
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        eraValidatorService: EraValidatorServiceProtocol,
        operationManager: OperationManagerProtocol,
        chainRegistry: ChainRegistryProtocol,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        output: YourValidatorListPoolStrategyOutput
    ) {
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.chainAsset = chainAsset
        self.wallet = wallet
        self.eraValidatorService = eraValidatorService
        self.operationManager = operationManager
        self.chainRegistry = chainRegistry
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.runtimeService = runtimeService
        self.validatorOperationFactory = validatorOperationFactory
        self.output = output
    }

    private func fetchPoolAccount(for type: PoolAccount) -> AccountId? {
        guard
            let modPrefix = "modl".data(using: .utf8),
            let palletIdData = palletId,
            let poolId = stakingPool?.id,
            let poolIdUintValue = UInt(poolId)
        else {
            return nil
        }

        var index: UInt8 = type.rawValue
        var poolIdValue = poolIdUintValue
        let indexData = Data(
            bytes: &index,
            count: MemoryLayout.size(ofValue: index)
        )

        let poolIdSize = MemoryLayout.size(ofValue: poolIdValue)
        let poolIdData = Data(
            bytes: &poolIdValue,
            count: poolIdSize
        )

        let emptyH256 = [UInt8](repeating: 0, count: 32)
        let poolAccountId = modPrefix + palletIdData + indexData + poolIdData + emptyH256

        return poolAccountId[0 ... 31]
    }

    private func provideNomination() {
        guard let accountId = fetchPoolAccount(for: .stash) else {
            return
        }

        fetchPoolNomination(poolStashAccountId: accountId)
    }

    private func fetchPoolNomination(poolStashAccountId: AccountId) {
        let nominationOperation = validatorOperationFactory.nomination(accountId: poolStashAccountId)
        nominationOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let nomination = try nominationOperation.targetOperation.extractNoCancellableResultData()
                self?.output?.didReceive(nomination: nomination)
                self?.nomination = nomination

                if nomination != nil {
                    self?.fetchValidators()
                } else {
                    DispatchQueue.main.async {
                        self?.output?.didReceiveValidators(result: .success(YourValidatorsModel.empty()))
                    }
                }
            } catch {
                self?.output?.didReceive(error: error)
            }
        }

        operationManager.enqueue(operations: nominationOperation.allOperations, in: .transient)
    }

    private func fetchPoolInfo(poolId: String) {
        let fetchPoolInfoOperation = stakingPoolOperationFactory.fetchBondedPoolOperation(poolId: poolId)
        fetchPoolInfoOperation.targetOperation.completionBlock = { [weak self] in
            do {
                let stakingPool = try fetchPoolInfoOperation.targetOperation.extractNoCancellableResultData()

                self?.stakingPool = stakingPool
                self?.provideNomination()
                self?.fetchValidators()
                DispatchQueue.main.async {
                    self?.output?.didReceive(stakingPool: stakingPool)
                }
            } catch {
                self?.output?.didReceive(error: error)
            }
        }

        operationManager.enqueue(operations: fetchPoolInfoOperation.allOperations, in: .transient)
    }

    private func createValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        if nomination.submittedIn >= activeEra {
            return createActiveValidatorsWrapper(
                for: nomination,
                stashAddress: stashAddress,
                activeEra: activeEra
            )
        } else {
            return createSelectedValidatorsWrapper(
                for: nomination,
                stashAddress: stashAddress,
                activeEra: activeEra
            )
        }
    }

    private func createActiveValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra _: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        let activeValidatorsWrapper = validatorOperationFactory.activeValidatorsOperation(
            for: stashAddress
        )

        let selectedValidatorsWrapper = validatorOperationFactory.pendingValidatorsOperation(
            for: nomination.targets
        )

        let mergeOperation = ClosureOperation<YourValidatorsModel> {
            let activeValidators = try activeValidatorsWrapper.targetOperation
                .extractNoCancellableResultData()
            let selectedValidators = try selectedValidatorsWrapper.targetOperation
                .extractNoCancellableResultData()

            return YourValidatorsModel(
                currentValidators: activeValidators,
                pendingValidators: selectedValidators
            )
        }

        mergeOperation.addDependency(selectedValidatorsWrapper.targetOperation)
        mergeOperation.addDependency(activeValidatorsWrapper.targetOperation)

        let dependencies = selectedValidatorsWrapper.allOperations + activeValidatorsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mergeOperation, dependencies: dependencies)
    }

    private func createSelectedValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra _: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        let selectedValidatorsWrapper = validatorOperationFactory.allSelectedOperation(
            by: nomination,
            nominatorAddress: stashAddress
        )

        let mapOperation = ClosureOperation<YourValidatorsModel> {
            let curentValidators = try selectedValidatorsWrapper.targetOperation
                .extractNoCancellableResultData()

            return YourValidatorsModel(
                currentValidators: curentValidators,
                pendingValidators: []
            )
        }

        mapOperation.addDependency(selectedValidatorsWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: selectedValidatorsWrapper.allOperations
        )
    }

    private func fetchValidators() {
        guard let nomination = nomination,
              let poolStashAddress = try? fetchPoolAccount(for: .stash)?.toAddress(using: chainAsset.chain.chainFormat),
              let activeEra = activeEraInfo?.index else {
            return
        }

        let validatorsWrapper = createValidatorsWrapper(
            for: nomination,
            stashAddress: poolStashAddress,
            activeEra: activeEra
        )

        validatorsWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try validatorsWrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveValidators(result: .success(result))
                } catch {
                    self?.output?.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: validatorsWrapper.allOperations, in: .transient)
    }

    private func clearAllSubscriptions() {
        clear(dataProvider: &poolMemberProvider)
        clear(dataProvider: &activeEraProvider)
    }

    private func setupSubscriptions() {
        if let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId {
            poolMemberProvider = subscribeToPoolMembers(for: accountId, chainAsset: chainAsset)
        }

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }

    private func fetchConstants() {
        fetchCompoundConstant(
            for: .nominationPoolsPalletId,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Data, Error>) in
            switch result {
            case let .success(palletId):
                self?.palletId = palletId
                self?.provideNomination()
                self?.fetchValidators()

            case .failure:
                break
            }

            self?.output?.didReceive(palletIdResult: result)
        }
    }
}

extension YourValidatorListPoolStrategy: YourValidatorListStrategy {
    func setup() {
        setupSubscriptions()
        fetchConstants()
    }

    func refresh() {
        clearAllSubscriptions()
        setupSubscriptions()
        fetchConstants()
    }
}

extension YourValidatorListPoolStrategy:
    RelaychainStakingLocalStorageSubscriber,
    RelaychainStakingLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<StakingPoolMember?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(poolMember):
            if let poolId = poolMember?.poolId.value {
                fetchPoolInfo(poolId: poolId.description)
            }

            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(stakeInfo: poolMember)
            }
        case let .failure(error):
            DispatchQueue.main.async { [weak self] in
                self?.output?.didReceive(error: error)
            }
        }
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        activeEraInfo = try? result.get()
        fetchValidators()
    }
}
