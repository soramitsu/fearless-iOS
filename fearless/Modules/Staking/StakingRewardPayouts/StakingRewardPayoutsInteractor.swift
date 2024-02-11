import UIKit
import RobinHood
import SSFUtils
import SSFModels

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!

    private let priceLocalSubscriber: PriceLocalStorageSubscriber
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    private let payoutService: PayoutRewardsServiceProtocol
    private let chainAsset: ChainAsset
    private let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let logger: LoggerProtocol?
    let connection: JSONRPCEngine

    private var priceProvider: AnySingleValueProvider<[PriceData]>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var payoutOperationsWrapper: CompoundOperationWrapper<PayoutsInfo>?

    deinit {
        let wrapper = payoutOperationsWrapper
        payoutOperationsWrapper = nil
        wrapper?.cancel()
    }

    init(
        priceLocalSubscriber: PriceLocalStorageSubscriber,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        payoutService: PayoutRewardsServiceProtocol,
        chainAsset: ChainAsset,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        logger: LoggerProtocol? = nil,
        connection: JSONRPCEngine
    ) {
        self.priceLocalSubscriber = priceLocalSubscriber
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.payoutService = payoutService
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.logger = logger
        self.connection = connection
        self.chainAsset = chainAsset
    }

    private func fetchEraCompletionTime() {
        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(
            for: connection,
            runtimeService: runtimeService
        )

        operationWrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let result = try operationWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter.didReceive(eraCountdownResult: .success(result))
                } catch {
                    self?.presenter.didReceive(eraCountdownResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: operationWrapper.allOperations, in: .transient)
    }
}

extension StakingRewardPayoutsInteractor: StakingRewardPayoutsInteractorInputProtocol {
    func setup() {
        priceProvider = priceLocalSubscriber.subscribeToPrice(for: chainAsset, listener: self)

        activeEraProvider = subscribeActiveEra(for: chainAsset.chain.chainId)

        fetchEraCompletionTime()
        reload()
    }

    func reload() {
        if chainAsset.chain.externalApi?.staking == nil {
            presenter.didReceive(result: .success(PayoutsInfo(activeEra: 0, historyDepth: 0, payouts: [])))
            return
        }

        guard payoutOperationsWrapper == nil else {
            return
        }

        let wrapper = payoutService.fetchPayoutsOperationWrapper()
        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    guard let currentWrapper = self?.payoutOperationsWrapper else {
                        return
                    }

                    self?.payoutOperationsWrapper = nil

                    let payoutsInfo = try currentWrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceive(result: .success(payoutsInfo))
                } catch {
                    if let serviceError = error as? PayoutRewardsServiceError {
                        self?.presenter.didReceive(result: .failure(serviceError))
                    } else {
                        self?.presenter.didReceive(result: .failure(.unknown))
                    }
                }
            }
        }

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)

        payoutOperationsWrapper = wrapper
    }
}

extension StakingRewardPayoutsInteractor: PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, chainAsset _: ChainAsset) {
        presenter.didReceive(priceResult: result)
    }
}

extension StakingRewardPayoutsInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chainId _: ChainModel.Id) {
        switch result {
        case .success:
            reload()
            fetchEraCompletionTime()
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
