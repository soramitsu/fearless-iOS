import UIKit
import RobinHood

final class StakingPoolInfoInteractor: RuntimeConstantFetching {
    // MARK: - Private properties

    private weak var output: StakingPoolInfoInteractorOutput?
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    private let chainAsset: ChainAsset
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let validatorOperationFactory: ValidatorOperationFactoryProtocol
    private let poolId: String
    private let stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        chainAsset: ChainAsset,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        validatorOperationFactory: ValidatorOperationFactoryProtocol,
        poolId: String,
        stakingPoolOperationFactory: StakingPoolOperationFactoryProtocol
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.chainAsset = chainAsset
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.validatorOperationFactory = validatorOperationFactory
        self.poolId = poolId
        self.stakingPoolOperationFactory = stakingPoolOperationFactory
    }

    private func prepareRecommendedValidatorList() {
        let wrapper = validatorOperationFactory.allElectedOperation()

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let validators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.output?.didReceiveValidators(result: .success(validators))
                } catch {
                    self?.output?.didReceiveValidators(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
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

        prepareRecommendedValidatorList()

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        fetchPoolInfo(poolId: poolId)
    }
}

extension StakingPoolInfoInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        output?.didReceivePriceData(result: result)
    }
}
