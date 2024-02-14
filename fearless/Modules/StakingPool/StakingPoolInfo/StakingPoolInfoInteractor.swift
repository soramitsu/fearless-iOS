import UIKit
import RobinHood
import SSFModels

final class StakingPoolInfoInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: StakingPoolInfoInteractorOutput?
    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    private(set) var stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let chainAsset: ChainAsset
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let poolId: String
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private let eraValidatorService: EraValidatorServiceProtocol

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        chainAsset: ChainAsset,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        poolId: String,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        eraValidatorService: EraValidatorServiceProtocol
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.chainAsset = chainAsset
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.validatorOperationFactory = validatorOperationFactory
        self.poolId = poolId
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.eraValidatorService = eraValidatorService
    }

    private func createValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress,
        activeEra: EraIndex
    ) -> CompoundOperationWrapper<YourValidatorsModel> {
        if nomination.submittedIn >= activeEra {
            return createActiveValidatorsWrapper(
                for: nomination,
                stashAddress: stashAddress
            )
        } else {
            return createSelectedValidatorsWrapper(
                for: nomination,
                stashAddress: stashAddress
            )
        }
    }

    private func createActiveValidatorsWrapper(
        for nomination: Nomination,
        stashAddress: AccountAddress
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
        stashAddress: AccountAddress
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

    private func fetchSelectedValidators(stashAddress: AccountAddress, nomination: Nomination, activeEra: EraIndex) {
        let operation = createValidatorsWrapper(for: nomination, stashAddress: stashAddress, activeEra: activeEra)

        operation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.output?.didReceive(nomination: nomination)

                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveValidators(validators: result)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }

    private func fetchPoolInfo(poolId: String) {
        let fetchPoolInfoOperation = stakingPoolOperationFactory.fetchBondedPoolOperation(poolId: poolId)
        fetchPoolInfoOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let stakingPool = try fetchPoolInfoOperation.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceive(stakingPool: stakingPool)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: fetchPoolInfoOperation.allOperations, in: .transient)
    }

    private func provideEraStakersInfo() {
        let operation = eraValidatorService.fetchInfoOperation()

        operation.completionBlock = {
            DispatchQueue.main.async { [weak self] in
                do {
                    let info = try operation.extractNoCancellableResultData()
                    self?.output?.didReceive(eraStakersInfo: info)
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }
}

// MARK: - StakingPoolInfoInteractorInput

extension StakingPoolInfoInteractor: StakingPoolInfoInteractorInput {
    func setup(with output: StakingPoolInfoInteractorOutput) {
        self.output = output

        fetchCompoundConstant(
            for: .nominationPoolsPalletId,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
        ) { [weak self] (result: Result<Data, Error>) in
            self?.output?.didReceive(palletIdResult: result)
        }

        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        fetchPoolInfo(poolId: poolId)

        provideEraStakersInfo()

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)
    }

    func fetchPoolNomination(poolStashAccountId: AccountId, activeEra: EraIndex) {
        guard let address = try? poolStashAccountId.toAddress(using: chainAsset.chain.chainFormat)
        else {
            return
        }

        let nominationOperation = validatorOperationFactory.nomination(accountId: poolStashAccountId)
        nominationOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let nomination = try nominationOperation.targetOperation.extractNoCancellableResultData()

                    if let nomination = nomination {
                        self?.fetchSelectedValidators(stashAddress: address, nomination: nomination, activeEra: activeEra)
                    } else {
                        self?.output?.didReceive(nomination: nomination)
                        self?.output?.didReceiveValidators(validators: YourValidatorsModel(currentValidators: [], pendingValidators: []))
                    }
                } catch {
                    self?.output?.didReceive(error: error)
                }
            }
        }

        operationManager.enqueue(operations: nominationOperation.allOperations, in: .transient)
    }
}

extension StakingPoolInfoInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        output?.didReceivePriceData(result: result)
    }
}

extension StakingPoolInfoInteractor:
    RelaychainStakingLocalStorageSubscriber,
    RelaychainStakingLocalSubscriptionHandler {
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        output?.didReceive(activeEra: result)
    }
}
