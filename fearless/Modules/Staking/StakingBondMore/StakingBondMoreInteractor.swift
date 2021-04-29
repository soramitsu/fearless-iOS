import RobinHood
import IrohaCrypto
import BigInt

final class StakingBondMoreInteractor {
    weak var presenter: StakingBondMoreInteractorOutputProtocol!

    // private let repository: AnyDataProviderRepository<AccountItem>
    private let priceProvider: AnySingleValueProvider<PriceData>
    private let balanceProvider: AnyDataProvider<DecodedAccountInfo>
    private let extrinsicService: ExtrinsicServiceProtocol
    private let runtimeService: RuntimeCodingServiceProtocol
    // private let rewardService: RewardCalculatorServiceProtocol
    private let operationManager: OperationManagerProtocol

    init(
        // repository: AnyDataProviderRepository<AccountItem>,
        priceProvider: AnySingleValueProvider<PriceData>,
        balanceProvider: AnyDataProvider<DecodedAccountInfo>,
        extrinsicService: ExtrinsicServiceProtocol,
        // rewardService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol
    ) {
        // self.repository = repository
        self.priceProvider = priceProvider
        self.balanceProvider = balanceProvider
        self.extrinsicService = extrinsicService
        // self.rewardService = rewardService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
    }

    private func subscribeToPriceChanges() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<PriceData>]) in
            if changes.isEmpty {
                self?.presenter.didReceive(price: nil)
            } else {
                for change in changes {
                    switch change {
                    case let .insert(item), let .update(item):
                        self?.presenter.didReceive(price: item)
                    case .delete:
                        self?.presenter.didReceive(price: nil)
                    }
                }
            }
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.presenter.didReceive(error: error)
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
}

extension StakingBondMoreInteractor: StakingBondMoreInteractorInputProtocol {
    func setup() {
        subscribeToPriceChanges()
    }

    private func createExtrinsicBuilderClosure(amount: BigUInt) -> ExtrinsicBuilderClosure {
        let callFactory = SubstrateCallFactory()

        let closure: ExtrinsicBuilderClosure = { builder in
            let call = try callFactory.bondExtra(amount: amount)
            _ = try builder.adding(call: call)
            return builder
        }

        return closure
    }

    func estimateFee(amount: BigUInt) {
        let closure = createExtrinsicBuilderClosure(amount: amount)
        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case let .success(info):
                    self?.presenter.didReceive(
                        paymentInfo: info,
                        for: amount
                    )
                case let .failure(error):
                    self?.presenter.didReceive(error: error)
                }
            }
        }
    }
}
