import UIKit
import RobinHood

final class StakingRewardPayoutsInteractor {
    weak var presenter: StakingRewardPayoutsInteractorOutputProtocol!

    let singleValueProviderFactory: SingleValueProviderFactoryProtocol

    private let payoutService: PayoutRewardsServiceProtocol
    private let assetId: WalletAssetId
    private let chain: Chain
    private let eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol
    private let operationManager: OperationManagerProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    private let logger: LoggerProtocol?

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var activeEraProvider: AnyDataProvider<DecodedActiveEra>?
    private var payoutOperationsWrapper: CompoundOperationWrapper<PayoutsInfo>?

    deinit {
        let wrapper = payoutOperationsWrapper
        payoutOperationsWrapper = nil
        wrapper?.cancel()
    }

    init(
        singleValueProviderFactory: SingleValueProviderFactoryProtocol,
        payoutService: PayoutRewardsServiceProtocol,
        assetId: WalletAssetId,
        chain: Chain,
        eraCountdownOperationFactory: EraCountdownOperationFactoryProtocol,
        operationManager: OperationManagerProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.singleValueProviderFactory = singleValueProviderFactory
        self.payoutService = payoutService
        self.assetId = assetId
        self.chain = chain
        self.eraCountdownOperationFactory = eraCountdownOperationFactory
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.logger = logger
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
        priceProvider = subscribeToPriceProvider(for: assetId)
        activeEraProvider = subscribeToActiveEraProvider(for: chain, runtimeService: runtimeService)
        reload()
    }

    // TODO: revert stubs
    // swiftlint:disable force_try
    func reload() {
        let payoutsInfo = PayoutsInfo(
            activeEra: 10,
            historyDepth: 2,
            payouts: [
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil),
                .init(era: 10, validator: try! Data(hexString: "0x11"), reward: 100, identity: nil)
            ]
        )
        presenter?.didReceive(result: .success(payoutsInfo))
//        guard payoutOperationsWrapper == nil else {
//            return
//        }
//
//        let wrapper = payoutService.fetchPayoutsOperationWrapper()
//        wrapper.targetOperation.completionBlock = { [weak self] in
//            DispatchQueue.main.async {
//                do {
//                    guard let currentWrapper = self?.payoutOperationsWrapper else {
//                        return
//                    }
//
//                    self?.payoutOperationsWrapper = nil
//
//                    let payoutsInfo = try currentWrapper.targetOperation.extractNoCancellableResultData()
//                    self?.presenter?.didReceive(result: .success(payoutsInfo))
//                } catch {
//                    if let serviceError = error as? PayoutRewardsServiceError {
//                        self?.presenter.didReceive(result: .failure(serviceError))
//                    } else {
//                        self?.presenter.didReceive(result: .failure(.unknown))
//                    }
//                }
//            }
//        }
//
//        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)
//
//        payoutOperationsWrapper = wrapper
    }
}

extension StakingRewardPayoutsInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        switch result {
        case let .success(priceData):
            presenter.didReceive(priceResult: .success(priceData))
        case let .failure(error):
            presenter.didReceive(priceResult: .failure(error))
        }
    }

    func handleActiveEra(result: Result<ActiveEraInfo?, Error>, chain _: Chain) {
        switch result {
        case let .success(activeEraInfo):
            if let eraIndex = activeEraInfo?.index {
                fetchEraCompletionTime(targerEra: eraIndex)
            }
        case let .failure(error):
            logger?.error(error.localizedDescription)
        }
    }
}
