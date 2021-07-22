import UIKit
import RobinHood

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!

    private let payoutService: PayoutRewardsServiceProtocol
    private let priceProvider: AnySingleValueProvider<PriceData>
    private let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private let activeEraProvider: AnyDataProvider<DecodedActiveEra>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol?

    private var payoutOperationsWrapper: CompoundOperationWrapper<PayoutsInfo>?

    deinit {
        let wrapper = payoutOperationsWrapper
        payoutOperationsWrapper = nil
        wrapper?.cancel()
    }

    init(
        payoutService: PayoutRewardsServiceProtocol,
        priceProvider: AnySingleValueProvider<PriceData>,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        activeEraProvider: AnyDataProvider<DecodedActiveEra>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.payoutService = payoutService
        self.priceProvider = priceProvider
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.activeEraProvider = activeEraProvider
        self.operationManager = operationManager
        self.logger = logger
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(priceResult: .success(nil))
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(priceResult: .success(item))
                    case .delete:
                        self?.presenter.didReceive(priceResult: .success(nil))
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(priceResult: .failure(error))
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        priceProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func subsribeToActiveEra() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<DecodedActiveEra>]) in
            if let activeEraInfo = changes.reduceToLastChange(), let eraIndex = activeEraInfo.item?.index {
                self?.fetchEraCompletionTime(targerEra: eraIndex)
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.logger?.error(error.localizedDescription)
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )
        activeEraProvider.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func fetchEraCompletionTime(targerEra: EraIndex) {
        let operationWrapper = eraCountdownOperationFactory.fetchCountdownOperationWrapper(targetEra: targerEra)
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
        subscribeToPriceChanges()
        subsribeToActiveEra()
        reload()
    }

    func reload() {
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
